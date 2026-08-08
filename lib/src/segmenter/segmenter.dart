import 'data/stems_data.g.dart' show kStemsPacked;

/// U+200B — inserted between recognised stems inside a Devanagari compound.
/// Downstream, [Transliterator] preserves this through Indic-to-Indic
/// conversion and turns it into a real space for Roman targets, so a split
/// compound reads with visible word-breaks in ITRANS / Roman-Readable output.
const String _zwsp = '\u200B';

/// Devanagari virama.
const String _virama = '\u094D';

/// Sanskrit compound splitter — literal, dictionary-driven.
///
/// The default stem set comes from
/// [csl-inflect](https://github.com/sanskrit-lexicon/csl-inflect)'s
/// `lexnorm-all2.txt` (MIT). No sandhi or nasal-alternation logic is
/// applied: a compound is split only when its surface form is exactly the
/// concatenation of two or more stems. Everything else is returned
/// unchanged. That keeps the transformation safe — never risks corrupting
/// input that a rule-based sandhi undo would.
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
  String insertBreaks(String input) {
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
        out.write(_splitToken(input.substring(i, j)));
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
  String _splitToken(String token) {
    if (_stems.contains(token)) return token;
    final List<int> boundaries = _aksharaBoundaries(token);
    // Need at least 2 * _minAksharas aksharas to produce two pieces.
    if (boundaries.length - 1 < 2 * _minAksharas) return token;

    // best[i] = segmentation of token[0..boundaries[i]] as list of piece
    // start-boundary indices. best[0] = <0> (empty prefix, one boundary
    // consumed). We track (pieces, lastPieceLen) for the tie-break.
    final List<_Best?> best =
        List<_Best?>.filled(boundaries.length, null, growable: false);
    best[0] = const _Best(<int>[0], 0);

    for (int end = 1; end < boundaries.length; end++) {
      for (int start = 0; start < end; start++) {
        final _Best? prev = best[start];
        if (prev == null) continue;
        final int endPos = boundaries[end];
        final int startPos = boundaries[start];
        // Piece must be ≥ minAksharas.
        if (end - start < _minAksharas) continue;
        final String piece = token.substring(startPos, endPos);
        if (!_stems.contains(piece)) continue;
        final _Best cand =
            _Best(<int>[...prev.pieces, end], end - start);
        final _Best? cur = best[end];
        if (cur == null || _isBetter(cand, cur)) {
          best[end] = cand;
        }
      }
    }

    final _Best? result = best[boundaries.length - 1];
    if (result == null || result.pieces.length < 3) {
      // pieces holds boundary indices; N pieces => N+1 boundary indices,
      // so <3 boundary indices = <2 real pieces = not a split.
      return token;
    }

    final StringBuffer out = StringBuffer();
    for (int p = 0; p < result.pieces.length - 1; p++) {
      if (p > 0) out.write(_zwsp);
      final int a = boundaries[result.pieces[p]];
      final int b = boundaries[result.pieces[p + 1]];
      out.write(token.substring(a, b));
    }
    return out.toString();
  }

  /// Fewer pieces beats more; among equal counts, longer last piece wins
  /// (Sanskrit compounds are head-final — the last stem carries the head
  /// noun, so preferring a longer tail matches the lexnorm decomposition
  /// convention).
  bool _isBetter(_Best a, _Best b) {
    if (a.pieces.length != b.pieces.length) {
      return a.pieces.length < b.pieces.length;
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
      // Consume any following combining marks that bind to this base.
      while (i < n) {
        final int nx = token.codeUnitAt(i);
        if (_isBinding(nx)) {
          i++;
        } else {
          break;
        }
      }
      // If the last consumed unit was a virama, this base is joined to the
      // next consonant — no akshara boundary yet.
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
    // Devanagari combining marks: U+0900..U+0903 (signs above/below),
    // U+093A..U+094F (vowel signs, nukta, virama, avagraha excluded),
    // U+0951..U+0954, U+0955..U+0957, U+0962..U+0963.
    if (c >= 0x0900 && c <= 0x0903) return true;
    if (c >= 0x093A && c <= 0x094F && c != 0x093D) return true; // exclude avagraha
    if (c >= 0x0951 && c <= 0x0957) return true;
    if (c == 0x0962 || c == 0x0963) return true;
    return false;
  }

  static const int _viramaCU = 0x094D;

  /// Devanagari letter (independent vowel or consonant or combining mark).
  static bool _isDevanagariLetter(int c) => c >= 0x0900 && c <= 0x097F;
}

class _Best {
  const _Best(this.pieces, this.lastPieceAksharas);

  /// Boundary indices (into the `boundaries` list) marking piece
  /// starts, plus the final boundary. E.g. `[0, 3, 7]` = 2 pieces, one from
  /// boundary 0..3 and one from boundary 3..7.
  final List<int> pieces;

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
