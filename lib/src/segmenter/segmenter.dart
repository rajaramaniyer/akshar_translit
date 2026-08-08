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
  String insertBreaks(String input, {bool allowVowelSandhi = false}) {
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
        out.write(_splitToken(input.substring(i, j), allowVowelSandhi));
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
  String _splitToken(String token, bool allowSandhi) {
    if (_stems.contains(token)) return token;
    final List<int> boundaries = _aksharaBoundaries(token);
    if (boundaries.length - 1 < 2 * _minAksharas) return token;

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
              if (!_stems.contains(pieceForm)) continue;

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
    if (result == null || result.forms.length < 2) return token;
    return result.forms.join(_zwsp);
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
      if (i > start) out.add(s.substring(start, i));
      start = i + 1;
    }
  }
  if (start < s.length) out.add(s.substring(start));
  return out;
}
