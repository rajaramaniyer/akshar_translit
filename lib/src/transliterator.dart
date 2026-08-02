import 'options.dart';
import 'script.dart';
import 'script_map.dart';

/// Aksharamukha's internal marker for the implicit `a` after a consonant.
const String _schwa = '\uF000';

/// Aksharamukha's internal marker distinguishing an independent vowel from a
/// vowel sign in Roman output.
const String _depV = '\u1E7F';

/// Zero-width joiner and non-joiner. These are stripped from input before
/// substitution to avoid breaking pattern matches.
const String _zwj = '\u200D';
const String _zwnj = '\u200C';

/// Vedic tonal marks (udatta, anudatta, dvi-svarita). Optionally stripped.
const List<String> _vedicSvaras = <String>['\u1CDA', '\u0951', '\u0952', '\u1CD0', '\u1CD1', '\u1CD2', '\u1CD3', '\u1CD4', '\u1CDB', '\u0951', '\u0952', '\u0953', '\u0954', '\u1CE5', '\u1CE6', '\u1CE7', '᳚', '॑', '॒'];

/// Diacritic marks that Aksharamukha's `ShiftDiacritics` reorders when a
/// vowel sign appears next to them. Matches
/// `GeneralMap.Diacritics` in the upstream project.
const List<String> _shiftableDiacritics = <String>[
  '\u02BD', // ʽ
  '\u00B7', // middle dot
  '\u00B9', // superscript 1
  '\u00B2', // superscript 2
  '\u00B3', // superscript 3
  '\u2074', // superscript 4
  '\u2081', // subscript 1
  '\u2082', // subscript 2
  '\u2083', // subscript 3
  '\u2084', // subscript 4
];

/// Escapes a literal for embedding in a Dart regex character alternation.
String _re(String s) {
  const Set<int> special = <int>{0x5C, 0x2E, 0x2A, 0x2B, 0x3F, 0x28, 0x29, 0x5B, 0x5D, 0x7B, 0x7D, 0x5E, 0x24, 0x7C, 0x2F};
  final StringBuffer out = StringBuffer();
  for (final int c in s.codeUnits) {
    if (special.contains(c)) out.write('\\');
    out.writeCharCode(c);
  }
  return out.toString();
}

/// Longest-first alternation for a list of literal strings.
String _alt(Iterable<String> parts) {
  final List<String> sorted = parts.where((String p) => p.isNotEmpty).toList()
    ..sort((String a, String b) => b.length.compareTo(a.length));
  return sorted.map(_re).join('|');
}

/// The core transliteration routine.
///
/// Ported from `aksharamukha.Convert.convertScript` covering only the
/// Indic→Indic and Indic→Roman branches that this package needs.
class Transliterator {
  const Transliterator();

  String convert(
    String input, {
    required Script from,
    required Script to,
    TransliterationOptions options = const TransliterationOptions(),
  }) {
    if (from == to) return input;
    final ScriptMap src = ScriptMap.of(from);
    final ScriptMap tgt = ScriptMap.of(to);

    String s = input;

    // Pre-process: strip joiners, optionally strip vedic marks, apply
    // source-specific normalisations.
    s = _removeJoiners(s);
    if (options.removeVedicSvaras) {
      for (final String v in _vedicSvaras) {
        s = s.replaceAll(v, '');
      }
    }
    s = _preprocessSource(s, from);

    final bool romanTarget =
        to == Script.itrans || to == Script.romanReadable;

    // Om is handled by the shared pair list below — Aksharamukha's extra
    // context-sensitive Om regex is only useful when source or target Om
    // clashes with other content, which is not the case for any of our
    // supported script pairs.

    final List<_Pair> pairs = _buildPairs(src, tgt, romanTarget: romanTarget);
    for (final _Pair p in pairs) {
      s = s.replaceAll(p.src, p.tgt);
    }

    if (romanTarget) {
      s = _fixRomanOutput(s, tgt);
      if (to == Script.romanReadable) {
        s = _fixRomanColloquial(s);
      }
    } else {
      s = _fixIndicOutput(s, tgt, options);
    }

    return s;
  }

  String _removeJoiners(String s) =>
      s.replaceAll(_zwj, '').replaceAll(_zwnj, '');

  String _preprocessSource(String s, Script from) {
    // Aksharamukha calls `ShiftDiacritics(reverse=True)` on the source string
    // so that user inputs like `கா²` (vowel-sign before the class marker) are
    // normalised to `க²ா`, letting the length-first pair substitution match
    // the multi-codepoint consonant.
    s = _shiftDiacriticsReverse(s, ScriptMap.of(from));
    switch (from) {
      case Script.tamil:
        // FixTamil(reverse=True): ஷ² is an alternate way to write Sanskrit ś
        // (native ஶ). Normalise so the general map matches.
        s = s.replaceAll('\u0BB7\u00B2', '\u0BB6');
        return s;
      case Script.devanagari:
        // Aksharamukha strips U+0954 (schwa accent) here. No-op for us.
        return s;
      default:
        return s;
    }
  }

  /// Reverse of `_shiftDiacritics`: `vs + diac` → `diac + vs`.
  String _shiftDiacriticsReverse(String s, ScriptMap src) {
    final String vs = _alt(src.vowelSignsAll);
    if (vs.isEmpty) return s;
    final String diac = _alt(_shiftableDiacritics);
    return s.replaceAllMapped(
      RegExp('($vs)($diac)'),
      (Match m) => '${m[2]}${m[1]}',
    );
  }

  /// Builds the (src, tgt) substitution pairs across every character group,
  /// sorted longest-source-first so multi-codepoint sequences (like Tamil's
  /// ³-annotated consonants or the Sinhala prenasalised sequences) are
  /// consumed before their sub-parts.
  List<_Pair> _buildPairs(
    ScriptMap src,
    ScriptMap tgt, {
    required bool romanTarget,
  }) {
    final List<_Pair> pairs = <_Pair>[];

    void addGroup(List<String> srcs, List<String> tgts) {
      assert(srcs.length == tgts.length,
          'group length mismatch: ${srcs.length} vs ${tgts.length}');
      for (int i = 0; i < srcs.length; i++) {
        if (srcs[i].isEmpty || tgts[i].isEmpty) continue;
        pairs.add(_Pair(srcs[i], tgts[i]));
      }
    }

    // Aksharamukha order: Aytham, Signs, CombiningSigns, VowelSigns, Vowels,
    // Consonants, Numerals. Om is folded in as a single-element group.
    addGroup(src.aytham, tgt.aytham);
    addGroup(src.signs, tgt.signs);
    addGroup(src.combiningSignsAll, tgt.combiningSignsAll);
    addGroup(src.vowelSignsAll, tgt.vowelSignsAll);
    if (romanTarget) {
      // Independent vowels get a leading DepV marker so that dropping the
      // schwa in front of a vowel-sign does not accidentally swallow a real
      // vowel that happens to look like one.
      final List<String> vs = tgt.vowelsAll.map((String v) => '$_depV$v').toList();
      addGroup(src.vowelsAll, vs);
      // Consonants get a trailing schwa marker so the implicit `a` can be
      // dropped or retained by later rules.
      final List<String> cs =
          tgt.consonantsAll.map((String c) => '$c$_schwa').toList();
      addGroup(src.consonantsAll, cs);
    } else {
      addGroup(src.vowelsAll, tgt.vowelsAll);
      addGroup(src.consonantsAll, tgt.consonantsAll);
    }
    addGroup(src.numerals, tgt.numerals);
    addGroup(src.om, tgt.om);

    pairs.sort((_Pair a, _Pair b) => b.src.length.compareTo(a.src.length));
    return pairs;
  }

  /// Cleanup passes for a Roman (ITRANS) target. Ported from
  /// `aksharamukha.ConvertFix.FixRomanOutput`.
  String _fixRomanOutput(String s, ScriptMap tgt) {
    final String virama = tgt.viramas[0];
    final String nukta = tgt.nuktas[0];
    final String vowelA = tgt.vowels[0];
    final String vowelI = tgt.vowels[2];
    final String vowelU = tgt.vowels[4];

    // Alternation of *every* target Roman token that can follow a schwa and
    // that means "no more `a` here". Aksharamukha lumps the virama marker in
    // with the vowel-sign list so `[schwa]×` (Sanskrit halant) also erases
    // the implicit `a`. That's why क्ष becomes `kSha` and not `kaSha`.
    final String vowelSignList = _alt(<String>[...tgt.vowelSignsAll]);
    final String vowelList = _alt(tgt.vowelsAll);

    // कि → k[schwa][depV]i : insert `_` so it renders `ka_i`, distinguishing
    // it from the `ai` diphthong.
    final String vowelIU = <String>[vowelI, vowelU].map(_re).join('|');
    s = s.replaceAllMapped(
      RegExp('(?<=${_re(_schwa)}${_re(_depV)})($vowelIU)'),
      (Match m) => '_${m[1]}',
    );

    // अइ अउ : likewise, insert `_` for consecutive independent vowels.
    s = s.replaceAllMapped(
      RegExp('(?<=${_re(_depV)}${_re(vowelA)}${_re(_depV)})($vowelIU)'),
      (Match m) => '_${m[1]}',
    );

    // Unaspirated stops followed by schwa+virama+ha (क्ह): insert `_` so it
    // renders `k_ha` and not `kha`.
    const List<int> unaspIdx = <int>[0, 2, 5, 7, 10, 12, 15, 17, 20, 22];
    final String unasp =
        unaspIdx.map((int i) => tgt.consonants[i]).map(_re).join('|');
    final String consH = _re(tgt.consonants[32]);
    s = s.replaceAllMapped(
      RegExp('($unasp)${_re(_schwa)}${_re(virama)}($consH)'),
      (Match m) => '${m[1]}_${m[2]}',
    );

    // क्अ : consonant + explicit halant + independent vowel → `_a` etc.
    s = s.replaceAllMapped(
      RegExp('${_re(_schwa)}(${_re(virama)})(?=$vowelList)'),
      (Match m) => '_${m[1]}',
    );

    // Move the nukta ahead of the schwa so it attaches to the consonant, not
    // to the following `a`.
    s = s.replaceAll('$_schwa$nukta', '$nukta$_schwa');

    // The core "kill implicit a" rule: schwa immediately before any
    // vowel-sign (including the virama marker) is stripped.
    s = s.replaceAll(RegExp('${_re(_schwa)}(?=$vowelSignList)'), '');

    // Everything else that's still a schwa is a bare consonant with implicit
    // `a`. Substitute the target's `a`.
    s = s.replaceAll(_schwa, vowelA);

    // Drop the DepV marker (was only there to protect independent vowels
    // during schwa handling).
    s = s.replaceAll(_depV, '');

    // Drop the internal virama marker (× for ITRANS).
    s = s.replaceAll(virama, '');

    return s;
  }

  /// Cleanup passes for an Indic target. Ported from
  /// `aksharamukha.ConvertFix.FixIndicOutput` plus the small set of
  /// default post-options that Aksharamukha applies per target.
  String _fixIndicOutput(String s, ScriptMap tgt, TransliterationOptions opts) {
    // Shift Tamil-style superscript diacritics past a following vowel sign so
    // they attach to the base consonant (only relevant when the target is
    // Tamil; a no-op for our targets but kept for parity).
    s = _shiftDiacritics(s, tgt);

    // Apply the target-specific defaults, with the user's overrides.
    switch (tgt.id) {
      case Script.kannada:
        if (opts.nasalToAnusvara ?? true) s = _nasalToAnusvara(s, tgt);
        if (opts.mToAnusvara ?? true) s = _mToAnusvara(s, tgt);
        break;
      case Script.telugu:
        if (opts.nasalToAnusvara ?? true) s = _nasalToAnusvara(s, tgt);
        if (opts.mToAnusvara ?? true) s = _mToAnusvara(s, tgt);
        if (opts.teluguRemoveShortEO ?? true) {
          s = s.replaceAll('\u0952\u200B', '');
        }
        break;
      case Script.malayalam:
        if (opts.malayalamAnusvaraNasal ?? true) {
          s = _malayalamAnusvaraNasal(s, tgt);
        }
        if (opts.mToAnusvara ?? true) s = _mToAnusvara(s, tgt);
        if (opts.malayalamRemoveHistorical ?? true) {
          s = s.replaceAll('\u0D29', '\u0D28');
        }
        // ChilluN with ZWJ+virama collapses to Chillu-N.
        s = s.replaceAll('\u0D28\u200D\u094D', '\u0D7B');
        break;
      case Script.devanagari:
      case Script.tamil:
      case Script.itrans:
      case Script.romanReadable:
        // Not target defaults; explicit user overrides still apply.
        if (opts.nasalToAnusvara == true) s = _nasalToAnusvara(s, tgt);
        if (opts.anusvaraToNasal == true) s = _anusvaraToNasal(s, tgt);
        if (opts.mToAnusvara == true) s = _mToAnusvara(s, tgt);
        break;
    }
    return s;
  }

  /// `k² + ா` → `k + ா + ²`. Only Tamil emits these superscripts today.
  String _shiftDiacritics(String s, ScriptMap tgt) {
    final String vs = _alt(tgt.vowelSignsAll);
    if (vs.isEmpty) return s;
    final String diac = _alt(_shiftableDiacritics);
    return s.replaceAllMapped(
      RegExp('($diac)($vs)'),
      (Match m) => '${m[2]}${m[1]}',
    );
  }

  /// Nasal + virama + class consonant → anusvara + consonant.
  String _nasalToAnusvara(String s, ScriptMap tgt) {
    const List<int> nasalIdx = <int>[4, 9, 14, 19, 24];
    const List<List<int>> classRanges = <List<int>>[
      <int>[0, 4],
      <int>[5, 9],
      <int>[10, 14],
      <int>[15, 19],
      <int>[20, 24],
    ];
    final String vir = tgt.viramas[0];
    final String anu = tgt.ayogavahas[1];
    for (int i = 0; i < 5; i++) {
      final String nasal = tgt.consonants[nasalIdx[i]];
      final String classAlt = _alt(tgt.consonants
          .sublist(classRanges[i][0], classRanges[i][1] + 1)
          .where((String c) => c != nasal));
      if (classAlt.isEmpty) continue;
      s = s.replaceAllMapped(
        RegExp('(?<!${_re(vir)})${_re(nasal)}${_re(vir)}($classAlt)'),
        (Match m) => '$anu${m[1]}',
      );
    }
    return s;
  }

  /// Anusvara + class consonant → class nasal + virama + consonant.
  String _anusvaraToNasal(String s, ScriptMap tgt) {
    const List<int> nasalIdx = <int>[4, 9, 14, 19, 24];
    const List<List<int>> classRanges = <List<int>>[
      <int>[0, 4],
      <int>[5, 9],
      <int>[10, 14],
      <int>[15, 19],
      <int>[20, 24],
    ];
    final String vir = tgt.viramas[0];
    final String anu = tgt.ayogavahas[1];
    final String nukta = tgt.nuktas[0];
    for (int i = 0; i < 5; i++) {
      final String nasal = tgt.consonants[nasalIdx[i]];
      final String classAlt = _alt(tgt.consonants
          .sublist(classRanges[i][0], classRanges[i][1] + 1));
      if (classAlt.isEmpty) continue;
      s = s.replaceAllMapped(
        RegExp('${_re(anu)}($classAlt)(?!${_re(nukta)})'),
        (Match m) => '$nasal$vir${m[1]}',
      );
    }
    return s;
  }

  /// Malayalam's traditional-orthography anusvara expansion. Aksharamukha
  /// applies this asymmetrically: velar `k` only (not kh/g/gh), palatal
  /// `c ch j` (not jh), full retroflex and dental classes, labial `p` only.
  String _malayalamAnusvaraNasal(String s, ScriptMap tgt) {
    final String vir = tgt.viramas[0];
    final String anu = tgt.ayogavahas[1];
    // Aksharamukha's `ListNNasal` (velar, palatal, retroflex, dental, labial)
    // paired with the asymmetric `ListCNasal`.
    const List<int> nasalIdx = <int>[4, 9, 14, 19, 24];
    const List<List<int>> ranges = <List<int>>[
      <int>[0, 0], // k only
      <int>[5, 7], // c ch j (not jh)
      <int>[10, 13], // ṭ ṭh ḍ ḍh
      <int>[15, 18], // t th d dh
      <int>[20, 20], // p only
    ];
    for (int i = 0; i < ranges.length; i++) {
      final String nasal = tgt.consonants[nasalIdx[i]];
      final String classAlt =
          _alt(tgt.consonants.sublist(ranges[i][0], ranges[i][1] + 1));
      if (classAlt.isEmpty) continue;
      s = s.replaceAllMapped(
        RegExp('${_re(anu)}($classAlt)'),
        (Match m) => '$nasal$vir${m[1]}',
      );
    }
    return s;
  }

  /// Word-final labial nasal + virama → anusvara (e.g., `म्` → `ं`).
  String _mToAnusvara(String s, ScriptMap tgt) {
    final String m = tgt.consonants[24];
    final String vir = tgt.viramas[0];
    final String anu = tgt.ayogavahas[1];
    // Aksharamukha requires the M+virama to not be followed by any of the
    // "character" tokens (i.e., end of word). We approximate with anything
    // that isn't a base consonant/vowel sign.
    final String contentAlt = _alt(<String>[
      ...tgt.consonantsAll,
      ...tgt.vowelsAll,
      ...tgt.combiningSignsAll,
      ...tgt.vowelSignsAll,
    ]);
    if (contentAlt.isEmpty) return s;
    return s.replaceAll(
      RegExp('${_re(m)}${_re(vir)}(?!$contentAlt)'),
      anu,
    );
  }

  /// Aksharamukha's `FixRomanColloquial`: anusvara-context expansion,
  /// palatal-nasal smoothing, and trimming of the leftover apostrophes and
  /// underscores that the base map / schwa handling leave behind.
  String _fixRomanColloquial(String s) {
    // Palatal nasal between vowels: `anja` → `anya`, at word edges too.
    s = s.replaceAllMapped(
      RegExp('([aiueo])nj([aeiou])'),
      (Match m) => '${m[1]}ny${m[2]}',
    );
    s = s.replaceAllMapped(
      RegExp(r'(\W)nj([aeiou])'),
      (Match m) => '${m[1]}ny${m[2]}',
    );
    s = s.replaceAllMapped(
      RegExp('^nj([aeiou])'),
      (Match m) => 'ny${m[1]}',
    );
    s = s.replaceAll('njnj', 'nny');

    // Anusvara (M) followed by a class initial: pick the natural English
    // spelling. Order matters — `Mk` → `ngk` happens first, then `ngk` → `nk`.
    const List<List<String>> mExpand = <List<String>>[
      <String>['Mk', 'ngk'],
      <String>['Mg', 'ngg'],
      <String>['Mc', 'njc'],
      <String>['Mj', 'njj'],
      <String>['Md', 'nd'],
      <String>['Mt', 'nt'],
      <String>['Mb', 'mb'],
      <String>['Mp', 'mp'],
    ];
    for (final List<String> pair in mExpand) {
      s = s.replaceAll(pair[0], pair[1]);
    }
    // Leftover anusvara: Aksharamukha emits a combining grapheme joiner so
    // the `m` doesn't visually fuse with the next character. Match that.
    s = s.replaceAll('M', 'm\u034F');

    // Second pass collapses the doubled-nasal clusters produced above and
    // any pre-existing sequences from Aksharamukha's base map.
    s = s.replaceAll('ngk', 'nk');
    s = s.replaceAll('ngg', 'ng');
    s = s.replaceAll('njc', 'nc');
    s = s.replaceAll('njj', 'nj');
    s = s.replaceAll('jnj', 'jny');

    // Aksharamukha additionally aspirates dental t/d for Tamil sources, but
    // its implementation over-applies (turns `th` → `thh` etc.). We omit
    // that step; readers of Tamil-source output get plain t/d.

    // Strip the disambiguating apostrophes and underscores that the base
    // map and schwa handling leave behind.
    s = s.replaceAll("'", '').replaceAll('_', '');

    return s;
  }
}

class _Pair {
  const _Pair(this.src, this.tgt);
  final String src;
  final String tgt;
}
