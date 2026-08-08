import 'data/stems_data.g.dart' show kStemsPacked;

/// U+200B — inserted between recognised stems inside a Devanagari compound.
/// Downstream, [Transliterator] preserves this through Indic-to-Indic
/// conversion and turns it into a real space for Roman targets, so a split
/// compound reads with visible word-breaks in ITRANS / Roman-Readable output.
const String _zwsp = '\u200B';

/// Fusible matras and the independent vowels each one unfuses into on the
/// right-hand piece's head, per the six vowel-coalescence rules:
///   a/ā + a/ā → ā       (matra ा  ↔ prepend आ / अ)
///   a/ā + i/ī → e       (matra े  ↔ prepend ई / इ)
///   a/ā + u/ū → o       (matra ो  ↔ prepend ऊ / उ)
///   a/ā + e   → ai      (matra ै  ↔ prepend ए)
///   a/ā + o   → au      (matra ौ  ↔ prepend ओ)
///
/// Long-vowel heads are listed first: they win the tie-breaker when both
/// short and long forms of the head are known stems, which matches the
/// idiomatic reading of most Sanskrit compounds (e.g. `yamaniyamāsana`
/// prefers `āsana` over `asana`).
const Map<int, List<String>> _fusibleHeadPrepends = <int, List<String>>{
  0x093E: <String>['\u0906', '\u0905'], // ा  → आ / अ
  0x0947: <String>['\u0908', '\u0907'], // े  → ई / इ
  0x094B: <String>['\u090A', '\u0909'], // ो  → ऊ / उ
  0x0948: <String>['\u090F'],           // ै  → ए
  0x094C: <String>['\u0913'],           // ौ  → ओ
};

const String _matraLongA = '\u093E';

bool _isFusibleMatra(int c) => _fusibleHeadPrepends.containsKey(c);

/// Common nominal case-endings, longest first. When
/// [DevanagariSegmenter.insertBreaks] runs with `allowInflectedTail: true`,
/// the *last* piece of a compound may match `stem + suffix` where `stem`
/// is in the dictionary and `suffix` is one of these.
///
/// This covers the accusative / nominative / genitive endings that show up
/// in devotional and epic Sanskrit — enough to segment lines like
/// `राधाकृष्णपदाम्बुजभृङ्गम्` where every noun compound ends in `-म्`,
/// `-आम्`, or `-आन्`. It is intentionally *not* a full paradigm table —
/// larger lists get combinatorially more likely to fire on non-inflected
/// tails and cause false splits.
const List<String> _terminalInflectSuffixes = <String>[
  'ाभ्याम्', // dual inst / dat / abl
  'ेभ्यः',   // pl dat / abl
  'ानाम्',   // gen pl (via a→ā sandhi)
  'ेषु',      // pl loc
  'ान्',      // acc pl m
  'ाम्',      // acc sg f  (also gen pl a-stem)
  'ैः',       // pl inst
  'ाः',      // nom / acc pl f
  'ौ',        // dual nom / acc / voc
  'म्',       // acc sg m/n  ← the biggest single winner
];

/// Sanskrit compound splitter — dictionary-driven.
///
/// The default stem set comes from
/// [csl-inflect](https://github.com/sanskrit-lexicon/csl-inflect)'s
/// `lexnorm-all2.txt` (MIT).
///
/// By default the splitter is *literal*: a compound is split only when its
/// surface form is exactly the concatenation of two or more stems. Pass
/// `allowVowelSandhi: true` (or, at the [Transliterator] layer, set
/// `TransliterationOptions.splitAcrossVowelSandhi`) to additionally allow
/// vowel-coalescence undo at seams. No consonant sandhi, visarga sandhi,
/// or nasal-alternation logic is applied.
class DevanagariSegmenter {
  DevanagariSegmenter._(this._stems, this._minAksharas);

  /// The package-bundled singleton with the csl-inflect stem set and a
  /// 2-akshara minimum piece length.
  factory DevanagariSegmenter.bundled() => _bundled;

  /// Provide a custom stem set — useful in tests, or if a caller wants to
  /// swap in domain-specific vocabulary.
  factory DevanagariSegmenter.custom(
    Set<String> stems, {
    int minAksharas = 2,
  }) =>
      DevanagariSegmenter._(stems, minAksharas);

  static final DevanagariSegmenter _bundled =
      DevanagariSegmenter._(_loadBundled(), 2);

  final Set<String> _stems;
  final int _minAksharas;

  /// Rewrites [input] by inserting U+200B between recognised stems inside
  /// each Devanagari token. Non-Devanagari runs (spaces, punctuation,
  /// digits) pass through untouched.
  ///
  /// When [allowVowelSandhi] is `true`, the splitter also considers the
  /// six vowel-coalescence unfusings at each seam. Pieces are then emitted
  /// in their *underlying* (dictionary) form — that is, the fused matra at
  /// a split point is rewritten to the two-vowel form. So the surface
  /// `यमनियमासन` (yamaniyamāsana) becomes `यम‌नियम‌आसन`, which
  /// transliterates to `yama niyama Asana` in ITRANS.
  ///
  /// When [allowInflectedTail] is `true`, the *last* piece of a compound
  /// may be a `stem + case-ending` pair rather than a bare stem — e.g. the
  /// devotional line `राधाकृष्णपदाम्बुजभृङ्गम्` can end in `भृङ्गम्`
  /// (`भृङ्ग` + acc-sg `म्`) which is not itself in the dictionary. Only a
  /// small closed list of common nominal endings is recognised; the last
  /// piece is emitted with its ending intact (surface preserved).
  ///
  /// When [allowGreedyFallback] is `true`, tokens of at least
  /// [greedyFallbackMinChars] code units that the DP couldn't fully cover
  /// are re-scanned left-to-right: at each position we insert a ZWSP after
  /// the *longest* prefix that is a recognised stem, then continue from
  /// there. Unrecognised runs between two known stems are absorbed into
  /// the trailing piece — so the output always covers the surface exactly,
  /// but individual pieces may not all be dictionary words. Useful for
  /// devotional / epic Sanskrit where compound coverage is sparse: a line
  /// like `प्राचेतसनारदप्रह्लादान्` will at least become
  /// `प्राचेतस\u200Bनारद\u200Bप्रह्लादान्` even though `प्रह्लाद`
  /// isn't in the bundled csl-inflect set.
  String insertBreaks(
    String input, {
    bool allowVowelSandhi = false,
    bool allowInflectedTail = false,
    bool allowGreedyFallback = false,
    int greedyFallbackMinChars = 16,
  }) {
    if (input.isEmpty) return input;
    final StringBuffer out = StringBuffer();
    int i = 0;
    final int n = input.length;
    while (i < n) {
      final int c = input.codeUnitAt(i);
      if (_isDevanagariLetter(c)) {
        int j = i;
        while (j < n && _isDevanagariLetter(input.codeUnitAt(j))) {
          j++;
        }
        out.write(
          _splitToken(input.substring(i, j), allowVowelSandhi,
              allowInflectedTail, allowGreedyFallback,
              greedyFallbackMinChars),
        );
        i = j;
      } else {
        out.writeCharCode(c);
        i++;
      }
    }
    return out.toString();
  }

  /// Returns the segmented form of a single Devanagari token, or the token
  /// itself if no valid full segmentation exists.
  String _splitToken(
    String token,
    bool allowSandhi,
    bool allowInflectedTail,
    bool allowGreedyFallback,
    int greedyMinChars,
  ) {
    if (_stems.contains(token)) return token;
    final List<int> boundaries = _aksharaBoundaries(token);
    if (boundaries.length - 1 < 2 * _minAksharas) {
      return allowGreedyFallback && token.length >= greedyMinChars
          ? _greedySplit(token, boundaries, allowInflectedTail)
          : token;
    }

    // best[b][ts] = best segmentation of token[0..boundaries[b]] whose
    // last piece has right-tail state `ts`:
    //   ts=0  literal (no fusion assumed at right seam)
    //   ts=1  underlying tail was short-a (surface matra dropped)
    //   ts=2  underlying tail was long-ā  (surface matra replaced with ा)
    // In non-sandhi mode only ts=0 is populated.
    final int nB = boundaries.length;
    final int lastIdx = nB - 1;
    final List<List<_Best?>> best = List<List<_Best?>>.generate(
        nB, (_) => <_Best?>[null, null, null],
        growable: false);
    best[0][0] = const _Best(<String>[], 0);

    for (int end = 1; end < nB; end++) {
      final bool isTerminal = end == lastIdx;
      final int endOffset = boundaries[end];
      final int matraAtEnd =
          isTerminal ? 0 : token.codeUnitAt(endOffset - 1);
      final bool endMatraFusible = _isFusibleMatra(matraAtEnd);

      for (int tailState = 0; tailState < 3; tailState++) {
        if (!allowSandhi && tailState != 0) continue;
        if (tailState != 0 && (isTerminal || !endMatraFusible)) continue;

        for (int start = 0; start < end; start++) {
          if (end - start < _minAksharas) continue;

          final bool isStart = start == 0;
          final int startOffset = boundaries[start];
          final int matraAtStart =
              isStart ? 0 : token.codeUnitAt(startOffset - 1);
          final bool startMatraFusible = _isFusibleMatra(matraAtStart);

          for (int prevTail = 0; prevTail < 3; prevTail++) {
            if (!allowSandhi && prevTail != 0) continue;
            final _Best? prev = best[start][prevTail];
            if (prev == null) continue;

            final List<String> headPrepends;
            if (isStart) {
              if (prevTail != 0) continue;
              headPrepends = const <String>[''];
            } else if (prevTail == 0) {
              headPrepends = const <String>[''];
            } else {
              if (!startMatraFusible) continue;
              headPrepends = _fusibleHeadPrepends[matraAtStart]!;
            }

            final String surfaceTail;
            if (tailState == 0) {
              surfaceTail = token.substring(startOffset, endOffset);
            } else if (tailState == 1) {
              surfaceTail = token.substring(startOffset, endOffset - 1);
            } else {
              surfaceTail =
                  token.substring(startOffset, endOffset - 1) + _matraLongA;
            }

            for (final String head in headPrepends) {
              final String pieceForm = head + surfaceTail;
              if (!_isValidPiece(
                pieceForm,
                isTerminal: end == lastIdx,
                allowInflectedTail: allowInflectedTail,
              )) continue;

              final _Best cand = _Best(
                <String>[...prev.forms, pieceForm],
                end - start,
              );
              final _Best? cur = best[end][tailState];
              if (cur == null || _isBetter(cand, cur)) {
                best[end][tailState] = cand;
              }
            }
          }
        }
      }
    }

    final _Best? result = best[lastIdx][0]; // terminal must be literal tail
    if (result != null && result.forms.length >= 2) {
      return result.forms.join(_zwsp);
    }
    return allowGreedyFallback && token.length >= greedyMinChars
        ? _greedySplit(token, boundaries, allowInflectedTail)
        : token;
  }

  /// Left-to-right longest-prefix scan used when the exact-cover DP can't
  /// segment the token. At each position we find the longest recognised
  /// stem starting there, emit a ZWSP after it, and continue. Aksharas
  /// with no known stem starting from them are absorbed into the piece
  /// preceding the next successful match (or into the trailing tail).
  ///
  /// The output always covers the token's surface — no rewriting — so
  /// individual pieces may not all be dictionary words, but the reader
  /// gets useful visual breaks in long compounds.
  String _greedySplit(
      String token, List<int> boundaries, bool allowInflectedTail) {
    final int nB = boundaries.length;
    final int n = nB - 1;
    if (n < 2) return token;

    final List<int> breaks = <int>[];
    int pos = 0;
    while (pos < n) {
      int found = -1;
      // Longest-first: try piece endings from n down to pos + 1. We
      // require pieces of at least 2 aksharas — a single-akshara stem
      // is almost always a preverb (प्र, आ, वि, सु…) rather than a
      // meaningful compound member, and breaking there creates noise.
      for (int end = n; end - pos >= 2; end--) {
        final String piece =
            token.substring(boundaries[pos], boundaries[end]);
        final bool stemOk = _stems.contains(piece) ||
            (end == n &&
                allowInflectedTail &&
                _isValidPiece(piece,
                    isTerminal: true, allowInflectedTail: true));
        if (!stemOk) continue;
        // Look-ahead: don't break here if the next akshara starts with a
        // phonotactically-impossible cluster — that means our surface
        // "match" is really the front of a larger fused compound (e.g.
        // matching `पदा` when the tail begins `म्बुज…`, or `चरणा` when
        // the tail begins `ङ्कि…`).
        //
        // On rejection we abandon this position entirely rather than
        // falling through to shorter candidates: those are almost always
        // over-eager preverb / verbal-root matches (`चर` for
        // `चरणाङ्कित`, `प्र` for `प्रह्लाद`) that produce more confusing
        // splits than absorbing the whole region.
        if (end < n &&
            _hasImpossibleWordInitial(
                token, boundaries[end], boundaries[end + 1])) {
          break;
        }
        found = end;
        break;
      }
      if (found == -1) {
        // Either no stem starts here at all, or the only candidates
        // failed look-ahead. Either way, advance one akshara — the
        // unrecognised akshara will be absorbed into the next piece.
        pos++;
        continue;
      }
      if (found < n) breaks.add(found);
      pos = found;
    }

    if (breaks.isEmpty) return token;

    final StringBuffer out = StringBuffer();
    int prev = 0;
    for (final int b in breaks) {
      out.write(token.substring(boundaries[prev], boundaries[b]));
      out.write(_zwsp);
      prev = b;
    }
    out.write(token.substring(boundaries[prev]));
    return out.toString();
  }

  /// A piece is valid if it's a stem itself, or — for the terminal piece
  /// when [allowInflectedTail] is on — a stem plus one of a small set of
  /// nominal case endings.
  bool _isValidPiece(
    String pieceForm, {
    required bool isTerminal,
    required bool allowInflectedTail,
  }) {
    if (_stems.contains(pieceForm)) return true;
    if (!isTerminal || !allowInflectedTail) return false;
    for (final String suf in _terminalInflectSuffixes) {
      if (!pieceForm.endsWith(suf)) continue;
      final int stemLen = pieceForm.length - suf.length;
      if (stemLen < 3) continue;
      if (_stems.contains(pieceForm.substring(0, stemLen))) return true;
    }
    return false;
  }

  /// Fewer pieces beats more; among equal counts, longer last piece wins
  /// (Sanskrit compounds are head-final — the last stem carries the head
  /// noun, so preferring a longer tail matches the lexnorm decomposition
  /// convention).
  bool _isBetter(_Best a, _Best b) {
    if (a.forms.length != b.forms.length) {
      return a.forms.length < b.forms.length;
    }
    return a.lastPieceAksharas > b.lastPieceAksharas;
  }

  /// Returns the code-unit offsets of every akshara boundary in [token],
  /// including 0 and `token.length`. An akshara boundary sits after any
  /// character that isn't a virama and whose next character isn't a vowel
  /// sign / modifier that binds to it.
  List<int> _aksharaBoundaries(String token) {
    final List<int> b = <int>[0];
    final int n = token.length;
    int i = 0;
    while (i < n) {
      final int c = token.codeUnitAt(i);
      i++;
      while (i < n) {
        final int nx = token.codeUnitAt(i);
        if (_isBinding(nx)) {
          i++;
        } else {
          break;
        }
      }
      if (c == _viramaCU || _endsWithVirama(token, i)) continue;
      b.add(i);
    }
    if (b.last != n) b.add(n);
    return b;
  }

  static bool _endsWithVirama(String s, int endExclusive) =>
      endExclusive > 0 && s.codeUnitAt(endExclusive - 1) == _viramaCU;

  /// True for vowel signs, nukta, virama, anusvara, visarga, candrabindu,
  /// vedic tonal marks — anything that combines onto a preceding base.
  static bool _isBinding(int c) {
    if (c >= 0x0900 && c <= 0x0903) return true;
    if (c >= 0x093A && c <= 0x094F && c != 0x093D) return true;
    if (c >= 0x0951 && c <= 0x0957) return true;
    if (c == 0x0962 || c == 0x0963) return true;
    return false;
  }

  static const int _viramaCU = 0x094D;

  static bool _isDevanagariLetter(int c) => c >= 0x0900 && c <= 0x097F;
}

class _Best {
  const _Best(this.forms, this.lastPieceAksharas);

  /// Dictionary/underlying form of each piece — what actually gets emitted
  /// between ZWSes. In literal mode this equals the surface substring; in
  /// sandhi mode it may differ (e.g. surface `नियमा` → underlying `नियम`).
  final List<String> forms;

  /// Length in aksharas of the last piece — used as the tie-breaker.
  final int lastPieceAksharas;
}

Set<String> _loadBundled() {
  final Set<String> out = <String>{};
  int start = 0;
  final String s = kStemsPacked;
  for (int i = 0; i < s.length; i++) {
    if (s.codeUnitAt(i) == 0x0A) {
      if (i > start && !_hasImpossibleWordInitial(s, start, i)) {
        out.add(s.substring(start, i));
      }
      start = i + 1;
    }
  }
  if (start < s.length && !_hasImpossibleWordInitial(s, start, s.length)) {
    out.add(s.substring(start));
  }
  return out;
}

/// Rejects csl-inflect decomposition artifacts whose first akshara is a
/// consonant + virama cluster that Sanskrit phonotactics never allow
/// word-initially. Two families:
///   1. Homorganic nasal + plosive (ङ्क, ञ्च, ण्ट, न्त, म्प …). These are
///      always word-medial; entries like `म्बुज` are mis-splits of words
///      like `पदाम्बुज`.
///   2. Any `र्…` or `ल्…` cluster. There is no such Sanskrit word-initial;
///      `र` appears vowel-initial as `ऋ` and both `र` / `ल` appear only as
///      the *second* element of a cluster. Entries like `र्थ` are
///      mis-splits of `अर्थ`.
bool _hasImpossibleWordInitial(String s, int start, int end) {
  if (end - start < 3) return false;
  if (s.codeUnitAt(start + 1) != 0x094D) return false;
  final int c0 = s.codeUnitAt(start);
  if (c0 == 0x0930 || c0 == 0x0932) return true; // र् or ल् — always invalid
  final int c2 = s.codeUnitAt(start + 2);
  switch (c0) {
    case 0x0919: // ङ + kavarga
      return c2 >= 0x0915 && c2 <= 0x0918;
    case 0x091E: // ञ + cavarga
      return c2 >= 0x091A && c2 <= 0x091D;
    case 0x0923: // ण + Tavarga
      return c2 >= 0x091F && c2 <= 0x0922;
    case 0x0928: // न + tavarga
      return c2 >= 0x0924 && c2 <= 0x0927;
    case 0x092E: // म + pavarga
      return c2 >= 0x092A && c2 <= 0x092D;
    default:
      return false;
  }
}
