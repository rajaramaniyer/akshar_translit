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

/// A split at position [seam] (in [token]) looks like it fell across a
/// hidden vowel-sandhi seam if the left piece ends in `a`/`ā` and the
/// right piece opens with a consonant carrying a "fused" matra (`े ो ै
/// ौ` — the classic products of `a/ā + i/u/e/o` sandhi). Callers use
/// this to reject splits like `हृद | योद्यान` (really `हृदय + उद्यान`)
/// when sandhi undo is off.
bool _looksLikeSandhiSeam(String token, int seam) {
  if (seam <= 0 || seam + 1 >= token.length) return false;
  final int leftLast = token.codeUnitAt(seam - 1);
  final bool leftAaEnding = leftLast == 0x093E ||
      (leftLast >= 0x0915 && leftLast <= 0x0939);
  if (!leftAaEnding) return false;
  final int rightFirst = token.codeUnitAt(seam);
  if (rightFirst < 0x0915 || rightFirst > 0x0939) return false;
  final int rightSecond = token.codeUnitAt(seam + 1);
  return rightSecond == 0x0947 || // े
      rightSecond == 0x094B ||    // ो
      rightSecond == 0x0948 ||    // ै
      rightSecond == 0x094C;      // ौ
}

/// Common nominal case-endings, longest first, paired with the minimum
/// stem length (in code units) required for the match to fire. Longer,
/// distinctive suffixes like `ाभ्याम्` are unambiguous enough that we can
/// safely accept a 2-char stem (`कर`, `पद`); shorter suffixes like `म्`
/// or `ौ` need a 3+-char stem so common verbal roots (`नह`, `कह`) don't
/// spuriously fire as inflected nominals.
///
/// When [DevanagariSegmenter.insertBreaks] runs with
/// `allowInflectedTail: true`, the *last* piece of a compound may match
/// `stem + suffix` where `stem` is in the dictionary.
///
/// Covers the accusative / nominative / genitive endings that show up
/// in devotional and epic Sanskrit — enough to segment lines like
/// `राधाकृष्णपदाम्बुजभृङ्गम्` where every noun compound ends in `-म्`,
/// `-आम्`, or `-आन्`. Intentionally *not* a full paradigm table —
/// larger lists get combinatorially more likely to fire on non-inflected
/// tails and cause false splits.
///
/// Entries are `(surfaceSuffix, minStemLenChars, stemRestore)`. When a
/// piece ends in `surfaceSuffix`, the stem is `piece[:-len(suffix)] +
/// stemRestore` — non-empty `stemRestore` recovers a stem-final vowel
/// that lengthens or fuses into the suffix (e.g. `आदि + n → आदीन्`, the
/// i-stem acc.pl.m. — surface has `ीन्`, dictionary has `आदि`).
const List<(String, int, String)> _terminalInflectSuffixes =
    <(String, int, String)>[
  ('ाभ्याम्', 2, ''), // dual inst / dat / abl
  ('ेभ्यः', 2, ''),   // pl dat / abl
  ('ानाम्', 2, ''),   // gen pl (via a→ā sandhi)
  ('ेषु', 2, ''),     // pl loc
  ('भिः', 2, ''),     // pl inst (i/u/consonant stems: हरिभिः, कविभिः)
  ('ान्', 3, ''),     // acc pl m
  ('ाम्', 3, ''),     // acc sg f  (also gen pl a-stem)
  ('ैः', 3, ''),      // pl inst
  ('ाः', 3, ''),      // nom / acc pl f
  ('ौ', 3, ''),       // dual nom / acc / voc
  ('म्', 3, ''),      // acc sg m/n  ← the biggest single winner
  ('ीन्', 3, 'ि'),    // i-stem acc.pl.m. (आदि → आदीन्)
  ('िः', 3, 'ि'),     // nom sg m i-stem (हरि → हरिः, कवि → कविः)
  ('ुः', 3, 'ु'),     // nom sg m u-stem (गुरु → गुरुः)
];

/// Visarga-ending inflectional suffixes attested at end of Sanskrit
/// words. Used *only* by the visarga-sandhi preprocess pass to
/// validate that a candidate LEFT chunk (with visarga restored) looks
/// like a real inflected form. Ordered longest-first. Each entry is
/// `(surface, minStemLen)`, minStemLen in code units.
const List<(String, int)> _visargaEndings = <(String, int)>[
  ('ेभ्यः', 3),
  ('भ्यः', 3),
  ('भिः', 3),
  ('ैः', 3),
  ('ोः', 3),
  ('ेः', 3),
  ('ीः', 3),
  ('ूः', 3),
  ('ुः', 3),
  ('िः', 3),
  ('ाः', 3),
];

/// Strict subset of [_visargaEndings] — used for the `-ष्ट/ठ` and
/// `-स्त/थ` surface patterns, whose intra-word cluster ambiguity is
/// severe (`आविष्ट`, `प्रविष्ट`, `अस्ति`, `कष्ट`, etc.). Only accept
/// visarga seams here when the LEFT ends in a distinctive
/// multi-akshara suffix that's rare in unrelated intra-word clusters.
const List<(String, int)> _strictVisargaEndings = <(String, int)>[
  ('ेभ्यः', 3),
  ('भ्यः', 3),
  ('भिः', 3),
  ('ैः', 3),
  ('ाः', 3),
];

/// Map from vowel matra to corresponding independent vowel. Used only
/// by the visarga preprocess to reconstruct form-(b) surfaces —
/// `-भिराविष्टम्` (`-भिः + आविष्टम्` written with the following `आ`
/// absorbed as an `ा` matra on the visarga-transformed `र`) — into
/// their split underlying form.
const Map<int, int> _matraToIndependentVowel = <int, int>{
  0x093E: 0x0906, // ा → आ
  0x093F: 0x0907, // ि → इ
  0x0940: 0x0908, // ी → ई
  0x0941: 0x0909, // ु → उ
  0x0942: 0x090A, // ू → ऊ
  0x0947: 0x090F, // े → ए
  0x0948: 0x0910, // ै → ऐ
  0x094B: 0x0913, // ो → ओ
  0x094C: 0x0914, // ौ → औ
};

/// Visarga-sandhi surface markers at a token-internal seam: the
/// halant-terminated consonant that *replaces* the underlying `-ः`
/// depends on the following sound. Keys are the halant consonant
/// (`र`/`श`/`ष`/`स`) code units; values decide whether a given
/// next-character makes it a valid visarga-sandhi surface.
///
///   `-र्` → visarga → `r` before vowel or voiced consonant (only after
///                     a non-`a`/`ā` preceding vowel).
///   `-श्` → visarga → `ś` before palatal `च` or `छ`.
///   `-ष्` → visarga → `ṣ` before retroflex `ट` or `ठ`.
///   `-स्` → visarga → `s` before dental `त` or `थ`.
bool _visargaSurfaceMatches(int halantCons, int nextCh) {
  switch (halantCons) {
    case 0x0930: // र
      return _isVowelOrVoicedConsonantStart(nextCh);
    case 0x0936: // श
      return nextCh == 0x091A || nextCh == 0x091B;
    case 0x0937: // ष
      return nextCh == 0x091F || nextCh == 0x0920;
    case 0x0938: // स
      return nextCh == 0x0924 || nextCh == 0x0925;
    default:
      return false;
  }
}

/// True if [c] is an independent Devanagari vowel or a voiced Devanagari
/// consonant. Used by the visarga → `r` rule.
bool _isVowelOrVoicedConsonantStart(int c) {
  // Independent vowels: अ..औ + short ऍ/ऑ range.
  if (c >= 0x0904 && c <= 0x0914) return true;
  // Consonants: allow the voiced set only.
  if (c < 0x0915 || c > 0x0939) return false;
  // Voiceless (or self `र`): excluded.
  const Set<int> excluded = <int>{
    0x0915, // क
    0x0916, // ख
    0x091A, // च
    0x091B, // छ
    0x091F, // ट
    0x0920, // ठ
    0x0924, // त
    0x0925, // थ
    0x092A, // प
    0x092B, // फ
    0x0930, // र (self — avoid geminate weirdness)
    0x0936, // श
    0x0937, // ष
    0x0938, // स
  };
  return !excluded.contains(c);
}

/// Sanskrit compound splitter — dictionary-driven.
///
/// **Purpose of the emitted ZWS characters.** Every U+200B this class
/// inserts is a *line-wrap hint* for downstream renderers, not a claim
/// that the two neighbouring pieces are the only or "correct" way to
/// analyse the compound. The goal is to help a long devotional /
/// classical Sanskrit compound wrap gracefully on narrow screens while
/// still reading naturally to a Sanskrit-literate eye. It is
/// deliberately *not* the goal to expose every possible sub-stem the
/// lexicon can recognise: over-splitting (fragmenting `भजितम्` into
/// `भजि|तम्`, or breaking short tokens like `अंशकरण`) makes text
/// harder to read, not easier. Future maintainers: if you find
/// yourself adding logic that produces *more* breaks on already-short
/// or already-wrappable tokens, you are probably fighting the design.
///
/// The default stem set comes from
/// [csl-inflect](https://github.com/sanskrit-lexicon/csl-inflect)'s
/// `lexnorm-all2.txt` (MIT).
///
/// By default the splitter is *literal*: seams are emitted only where
/// the character immediately before and after the seam are unchanged
/// from the input surface (no vowel-fusion has to be undone at that
/// seam). Pass `allowVowelSandhi: true` (or, at the [Transliterator]
/// layer, set `TransliterationOptions.splitAcrossVowelSandhi`) to
/// instead emit the underlying dictionary forms of every piece — that
/// mode rewrites fused matras and is meant for callers who want to
/// *see* the sandhi undone (e.g. `yamaniyamāsana` → `yama niyama
/// Asana` in ITRANS). No consonant sandhi, visarga sandhi, or
/// nasal-alternation logic is applied.
class DevanagariSegmenter {
  DevanagariSegmenter._(this._stems, this._minAksharas);

  /// The package-bundled singleton with the csl-inflect stem set and a
  /// 2-akshara minimum piece length.
  factory DevanagariSegmenter.bundled() => _bundled;

  /// Segmenter that uses the bundled stem set *plus* [extraStems].
  /// Convenient for callers who want to teach the splitter a small set
  /// of names / domain words without providing a whole custom lexicon.
  factory DevanagariSegmenter.bundledPlus(
    Iterable<String> extraStems, {
    int minAksharas = 2,
  }) {
    final Set<String> merged = <String>{..._loadBundled(), ...extraStems};
    return DevanagariSegmenter._(merged, minAksharas);
  }

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

  /// Returns `true` if [form] is present in the loaded stem set. Exposed
  /// for tooling and diagnostics — inflected surface forms will return
  /// `false` (only bare-stem membership is reported).
  bool containsStem(String form) => _stems.contains(form);

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
    // Idempotence guard: a line that already contains a ZWS is assumed
    // pre-segmented (either by an earlier run or by hand) and passes
    // through untouched. Applied per-line so a partially edited document
    // still gets fresh segmentation on its unbroken lines.
    if (input.contains(_zwsp) && input.contains('\n')) {
      final List<String> lines = input.split('\n');
      final StringBuffer joined = StringBuffer();
      for (int li = 0; li < lines.length; li++) {
        final String line = lines[li];
        joined.write(line.contains(_zwsp)
            ? line
            : insertBreaks(line,
                allowVowelSandhi: allowVowelSandhi,
                allowInflectedTail: allowInflectedTail,
                allowGreedyFallback: allowGreedyFallback,
                greedyFallbackMinChars: greedyFallbackMinChars));
        if (li < lines.length - 1) joined.write('\n');
      }
      return joined.toString();
    }
    if (input.contains(_zwsp)) return input;
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

  /// Minimum length (code units) at which a token is a candidate for
  /// segmentation at all. ZWS is a line-wrap hint, not an exhaustive
  /// word-boundary marker — a short token wraps as one unit anyway, and
  /// fragmenting it (`भजितम्` → `भजि|तम्`) hurts readability without
  /// helping wrap.
  static const int _minTokenSplitChars = 9;

  /// Trigger for the greedy LTR + RTL refinement passes: a surface piece
  /// this long or longer will be handed to greedy for a second look. Set
  /// slightly higher than [_minTokenSplitChars] because we only want to
  /// pull the messier greedy walker out for pieces that genuinely won't
  /// fit on a narrow line.
  static const int _greedyRefineMinChars = 11;

  /// Returns the segmented form of a single Devanagari token, or the token
  /// itself if no valid full segmentation exists.
  ///
  /// **Intent of every ZWS this method emits.** Downstream renderers
  /// treat U+200B as an *optional* line-break opportunity. The goal is
  /// therefore to help a long Sanskrit compound wrap gracefully — it is
  /// NOT to expose every possible sub-stem the lexicon can recognise.
  /// A reader should be able to look at the pieces between ZWSes and
  /// read them as natural chunks; over-splitting (e.g. `भजितम्` →
  /// `भजि|तम्`, or `अंशकरण` at 6 chars) makes text harder to read, not
  /// easier. Future maintainers: please resist the temptation to add
  /// more breaks "because the lexicon can see them" — this is a
  /// deliberate design choice, not a limitation to work around.
  String _splitToken(
    String token,
    bool allowSandhi,
    bool allowInflectedTail,
    bool allowGreedyFallback,
    int greedyMinChars, {
    bool skipVisargaPreprocess = false,
  }) {
    if (_stems.contains(token)) return token;

    // Visarga-sandhi preprocess. Only fires in sandhi-on mode: the
    // caller has opted into "undo Sanskrit sandhi at word junctures",
    // which the flag [DevanagariSegmenter.insertBreaks]'s
    // `allowVowelSandhi` gates. Handles four surface patterns where a
    // trailing `-ः` (visarga) has been welded across a word juncture:
    //
    //   `-र्V`    — visarga → `r` before vowel / voiced consonant
    //               (also `-रा-` / `-रि-` etc., where the following
    //                indep vowel got written as a matra on `र`)
    //   `-श्च/छ`  — visarga → `ś` before palatal
    //   `-ष्ट/ठ`  — visarga → `ṣ` before retroflex
    //   `-स्त/थ`  — visarga → `s` before dental
    //
    // Each candidate seam is validated by restoring the visarga on
    // the LEFT chunk and checking it against a known visarga-carrying
    // inflected form (`-भिः`, `-ैः`, `-िः`, …) whose stem is
    // dictionary-recognised. In line with the rest of sandhi-on mode,
    // pieces are emitted in their **underlying** form — LEFT gets `-ः`
    // appended in place of the seam's surface consonant, and (for the
    // `-रा-` form) the RIGHT gets its starting vowel re-independent-ised
    // — so the ZWSes fall between clean dictionary-shaped chunks.
    if (allowSandhi && !skipVisargaPreprocess) {
      final List<_VisargaSeam> seams = _findVisargaSeams(token);
      if (seams.isNotEmpty) {
        final StringBuffer out = StringBuffer();
        int cursor = 0;
        String pendingPrefix = '';
        for (int idx = 0; idx <= seams.length; idx++) {
          final bool isLast = idx == seams.length;
          final int chunkEnd = isLast ? token.length : seams[idx].leftEnd;
          String chunk = pendingPrefix + token.substring(cursor, chunkEnd);
          if (!isLast) chunk = '$chunk\u0903'; // append visarga
          final String piece = _splitToken(
            chunk,
            allowSandhi,
            allowInflectedTail,
            allowGreedyFallback,
            greedyMinChars,
            skipVisargaPreprocess: true,
          );
          if (idx > 0) out.write(_zwsp);
          out.write(piece);
          if (!isLast) {
            cursor = seams[idx].rightStart;
            pendingPrefix = seams[idx].rightPrepend;
          }
        }
        return out.toString();
      }
    }

    // Sandhi-on mode preserves the older "emit underlying pieces" contract
    // — callers who explicitly asked to see sandhi undone want the
    // dictionary forms between ZWSes (surface `भवा` shown as `भव`,
    // `आदि`). Fall through to the simple DP + greedy pipeline unchanged.
    if (allowSandhi) {
      final List<int> boundaries = _aksharaBoundaries(token);
      if (boundaries.length - 1 < 2 * _minAksharas) {
        return allowGreedyFallback && token.length >= greedyMinChars
            ? _greedySplit(token, boundaries, allowInflectedTail, true)
            : token;
      }
      final _Best? cover =
          _dpBestCover(token, boundaries, true, allowInflectedTail);
      if (cover != null && cover.forms.length >= 2) {
        return cover.forms.join(_zwsp);
      }
      return allowGreedyFallback && token.length >= greedyMinChars
          ? _greedySplit(token, boundaries, allowInflectedTail, true)
          : token;
    }

    // Sandhi-off mode — the default, and where all our line-wrap tuning
    // happens. Three-step pipeline:
    //
    //   1. Search the whole token with sandhi undo *on*. This is our
    //      most powerful decomposition: it can see `कञ्ज + भव + आदि +
    //      सुर + गण + वाञ्छितम्` inside `कञ्जभवादिसुरगणवाञ्छितम्`
    //      even though the surface has `भव → आदि` and `गण → वाञ्` seams
    //      fused into `भवा…` and `णवा…`.
    //   2. Keep only seams that are *surface-safe* — i.e. the character
    //      immediately before and after the seam is unchanged from the
    //      input. That is what lets us insert a plain ZWS without ever
    //      rewriting the surface. Fused seams silently merge back onto
    //      the neighbouring piece.
    //   3. For any surviving surface piece longer than
    //      [_greedyRefineMinChars], take one more pass with the greedy
    //      left-to-right walk to catch simple `stem|stem` compounds the
    //      sandhi search missed (e.g. `बृन्दकूजितचरिताम्` →
    //      `बृन्द|कूजित|चरिताम्`).
    //   4. For any piece still longer than [_greedyRefineMinChars] after
    //      LTR, apply the greedy right-to-left walk. RTL catches
    //      compounds whose *head* isn't in the lexicon but whose tail
    //      chain is (e.g. `व्यत्यस्तारुणचरणाम्भोजम्` — `व्यत्यस्त` is
    //      missing, but `अम्भोजम्`, `चरणा`, `अरुण` are all findable
    //      when we walk backwards).
    if (token.length < _minTokenSplitChars) return token;

    final List<int> boundaries = _aksharaBoundaries(token);
    if (boundaries.length - 1 < 2 * _minAksharas) return token;

    // Step 1 + 2: sandhi-aware search, surface-safe emit.
    final _Best? cover =
        _dpBestCover(token, boundaries, true, allowInflectedTail);
    List<String> pieces;
    if (cover != null && cover.forms.length >= 2) {
      final String? rescued =
          _renderSurfaceSafeSeams(token, boundaries, cover);
      pieces = rescued == null ? <String>[token] : rescued.split(_zwsp);
    } else {
      pieces = <String>[token];
    }

    // Steps 3 + 4: greedy refinement of any long remaining piece. Greedy
    // only pulls substrings from its input token so every seam it emits
    // is surface-safe by construction. Gated by [allowGreedyFallback] so
    // callers that want *only* dictionary-clean seams can opt out.
    if (!allowGreedyFallback) return pieces.join(_zwsp);

    // Step 3: LTR greedy for pieces longer than the refine threshold.
    final List<String> afterLtr = <String>[];
    for (final String piece in pieces) {
      if (piece.length >= _greedyRefineMinChars) {
        final List<int> pB = _aksharaBoundaries(piece);
        if (pB.length - 1 >= 2 * _minAksharas) {
          afterLtr.addAll(
              _greedySplit(piece, pB, allowInflectedTail, false)
                  .split(_zwsp));
          continue;
        }
      }
      afterLtr.add(piece);
    }

    // Step 4: RTL greedy for pieces LTR still couldn't shorten below the
    // refine threshold. LTR that already produced short pieces is left
    // alone.
    final List<String> afterRtl = <String>[];
    for (final String piece in afterLtr) {
      if (piece.length >= _greedyRefineMinChars) {
        final List<int> pB = _aksharaBoundaries(piece);
        if (pB.length - 1 >= 2 * _minAksharas) {
          afterRtl.addAll(
              _greedySplitRtl(piece, pB, allowInflectedTail).split(_zwsp));
          continue;
        }
      }
      afterRtl.add(piece);
    }
    return afterRtl.join(_zwsp);
  }

  /// Bottom-up DP that finds the best full-cover segmentation of [token].
  /// Returns `null` when no valid cover exists.
  _Best? _dpBestCover(
    String token,
    List<int> boundaries,
    bool allowSandhi,
    bool allowInflectedTail,
  ) {
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
    best[0][0] = const _Best(
        <String>[], <int>[], <int>[], 0, 1 << 30, 0);

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
          // Sandhi mode lets a head-prepend (`अ`, `आ`, `इ`, …) contribute
          // one underlying akshara, so surface pieces of `_minAksharas - 1`
          // may still be legitimate — we recheck head-empty pieces below.
          final int surfLower = allowSandhi ? _minAksharas - 1 : _minAksharas;
          if (end - start < surfLower) continue;

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
              // Head-empty pieces still require the full surface minimum.
              if (head.isEmpty && end - start < _minAksharas) continue;
              final String pieceForm = head + surfaceTail;
              if (!_isValidPiece(
                pieceForm,
                isTerminal: end == lastIdx,
                allowInflectedTail: allowInflectedTail,
              )) continue;

              final int pieceAks = end - start;
              final int newMin = pieceAks < prev.minPieceAksharas
                  ? pieceAks
                  : prev.minPieceAksharas;
              final _Best cand = _Best(
                <String>[...prev.forms, pieceForm],
                <int>[...prev.endBoundaries, end],
                <int>[...prev.tailStates, tailState],
                pieceAks,
                newMin,
                prev.sandhiSeamCount + (tailState == 0 ? 0 : 1),
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

    return best[lastIdx][0]; // terminal must be literal tail
  }

  /// Given a sandhi-aware DP cover, emit ZWSPs only at the seams that lie
  /// on a real akshara boundary in the surface — i.e., seams where the
  /// ending piece has `tailState == 0`, meaning no matra was fused there.
  /// Returns `null` when no such seam exists.
  String? _renderSurfaceSafeSeams(
    String token,
    List<int> boundaries,
    _Best cover,
  ) {
    if (cover.forms.length < 2) return null;

    final List<int> safeBreaks = <int>[];
    for (int i = 0; i < cover.forms.length - 1; i++) {
      if (cover.tailStates[i] == 0) {
        safeBreaks.add(boundaries[cover.endBoundaries[i]]);
      }
    }
    if (safeBreaks.isEmpty) return null;

    final StringBuffer out = StringBuffer();
    int prev = 0;
    for (final int p in safeBreaks) {
      out.write(token.substring(prev, p));
      out.write(_zwsp);
      prev = p;
    }
    out.write(token.substring(prev));
    return out.toString();
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
  String _greedySplit(String token, List<int> boundaries,
      bool allowInflectedTail, bool allowSandhi) {
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
        // Sandhi-seam guard: without sandhi undo, a seam with the
        // classic `a/ā | Cे/ो/ै/ौ` signature is almost certainly slicing
        // a fused akshara (e.g. `हृदय + उद्यान` → `हृदयोद्यान` shown as
        // `हृद | योद्यान`). Reject *unless* the right side actually
        // begins a known stem — that rules out the garbage-tail case
        // without breaking legit compounds like `युत | कोमल`.
        if (!allowSandhi && end < n &&
            _looksLikeSandhiSeam(token, boundaries[end]) &&
            !_anyStemStartsAt(token, boundaries, end)) {
          continue;
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

    // Trailing residue < 2 aksharas (typically a stray `म्` / `न्` / `त्`
    // that the DP couldn't attach) — drop the last break so it fuses
    // back onto the previous piece.
    while (breaks.isNotEmpty && n - breaks.last < 2) {
      breaks.removeLast();
    }

    // RTL rescue: after LTR completes, the trailing piece may still be a
    // clean stem + inflection whose head isn't in the dictionary — e.g.
    // `प्रमुखार्चितचरणान्` after `ब्रह्म|रुद्र|…` (or the whole token
    // when LTR found nothing). Peel the longest recognised inflected
    // terminal off that trailing piece and leave the head as an
    // absorbed piece. Bare-stem tails are already handled by LTR
    // greedy and short ones (like `तम्`) sneaking through here would
    // create meaningless heads.
    if (allowInflectedTail) {
      final int tailStart = breaks.isEmpty ? 0 : breaks.last;
      final int tailLen = n - tailStart;
      if (tailLen >= 2 * _minAksharas) {
        final String trailing =
            token.substring(boundaries[tailStart], boundaries[n]);
        final bool trailingValid = _stems.contains(trailing) ||
            _isValidPiece(trailing,
                isTerminal: true, allowInflectedTail: true);
        if (!trailingValid) {
          for (int mid = tailStart + _minAksharas;
              mid <= n - _minAksharas;
              mid++) {
            final String tail =
                token.substring(boundaries[mid], boundaries[n]);
            // Inflected match only — reject bare stems (LTR's job).
            final bool ok = !_stems.contains(tail) &&
                _isValidPiece(tail,
                    isTerminal: true, allowInflectedTail: true);
            if (!ok) continue;
            if (!allowSandhi &&
                _looksLikeSandhiSeam(token, boundaries[mid])) {
              continue;
            }
            breaks.add(mid);
            break;
          }
        }
      }
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

  /// Right-to-left mirror of [_greedySplit]. Walks from the token's tail
  /// backwards: at each position it looks for the *longest* piece that
  /// ends there and is a known stem (or, on the very first iteration,
  /// a valid inflected terminal). Complementary to LTR — LTR fails when
  /// the token's *head* isn't in the lexicon (`व्यत्यस्त` missing means
  /// no stem starts at position 0), but RTL can still peel a valid tail
  /// like `अम्भोजम्`, `चरणा`, `अरुण` off the back.
  ///
  /// No sandhi-undo — every seam is a literal akshara boundary of the
  /// input surface, so it's always safe to emit a ZWS there.
  String _greedySplitRtl(String token, List<int> boundaries,
      bool allowInflectedTail) {
    final int n = boundaries.length - 1;
    if (n < 2 * _minAksharas) return token;

    // RTL requires a higher per-piece floor than LTR: it only fires on
    // pieces the earlier passes couldn't cover, so bare 2-akshara dict
    // hits (`जम्`, `तम्`, `कर`) are almost always noise fragments of a
    // longer word rather than real compound tails.
    const int _rtlMinAksharas = 3;
    if (n < 2 * _rtlMinAksharas) return token;

    // Break points stored as boundary-indices; filled while walking
    // right-to-left, sorted ascending at the end.
    final List<int> breaks = <int>[];
    int end = n;
    bool firstIter = true;
    while (end >= 2 * _rtlMinAksharas) {
      int foundStart = -1;
      // Longest-first: smallest [start] gives longest piece.
      for (int start = 0; end - start >= _rtlMinAksharas; start++) {
        // Leading piece must itself be ≥ [_rtlMinAksharas] aksharas so
        // we don't strand a preverb (`प्र`, `वि`, …) at the front.
        if (start > 0 && start < _rtlMinAksharas) continue;
        final String piece =
            token.substring(boundaries[start], boundaries[end]);
        final bool stemOk = _stems.contains(piece) ||
            (firstIter && end == n && allowInflectedTail &&
                _isValidPiece(piece,
                    isTerminal: true, allowInflectedTail: true));
        if (!stemOk) continue;
        // Look-back: don't break here if the previous akshara ends with
        // a phonotactically-impossible cluster from the *left* piece's
        // perspective. We reuse the same "impossible word-initial"
        // check on `boundaries[start]..boundaries[start+1]` — a break
        // that produces `_greedySplit`-style garbage on either side is
        // rejected here too.
        if (start > 0 &&
            _hasImpossibleWordInitial(
                token, boundaries[start], boundaries[start + 1])) {
          continue;
        }
        foundStart = start;
        break;
      }
      if (foundStart == -1) {
        end--;
        continue;
      }
      if (foundStart > 0) breaks.add(foundStart);
      end = foundStart;
      firstIter = false;
    }

    if (breaks.isEmpty) return token;
    breaks.sort();

    // Drop any leading break that would leave a sub-min-akshara head.
    while (breaks.isNotEmpty && breaks.first < _rtlMinAksharas) {
      breaks.removeAt(0);
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


  bool _anyStemStartsAt(String token, List<int> boundaries, int startIdx) {
    final int nB = boundaries.length;
    final int startOff = boundaries[startIdx];
    for (int end = startIdx + _minAksharas; end < nB; end++) {
      if (_stems.contains(token.substring(startOff, boundaries[end]))) {
        return true;
      }
    }
    return false;
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
    for (final (String suf, int minStemLen, String stemRestore)
        in _terminalInflectSuffixes) {
      if (!pieceForm.endsWith(suf)) continue;
      final int stemLen = pieceForm.length - suf.length;
      if (stemLen + stemRestore.length < minStemLen) continue;
      final String stem = pieceForm.substring(0, stemLen) + stemRestore;
      if (_stems.contains(stem)) return true;
    }
    return false;
  }

  /// Scan [token] left-to-right for surface visarga-sandhi markers that
  /// look like they've welded two words together at a juncture. Handles
  /// two writing conventions:
  ///
  ///   Form (a) — halant + independent vowel / consonant:
  ///     `-र्V`  after non-`a`/`ā` vowel, `-श्च/छ`, `-ष्ट/ठ`, `-स्त/थ`.
  ///
  ///   Form (b) — `र` written with a vowel matra (only `र`, because it
  ///     is the only visarga-transformed consonant that can precede an
  ///     independent vowel that then gets absorbed as a matra):
  ///     `-र + <matra>` at an akshara boundary, after non-`a`/`ā` vowel.
  ///     E.g. `-भिराविष्टम्` = `-भिः + आविष्टम्` written with `आ`
  ///     collapsed onto `र` as `ा`.
  ///
  /// At each candidate the LEFT half is provisionally reconstructed by
  /// restoring `-ः` and checked with [_isValidVisargaTail]. Returns a
  /// [_VisargaSeam] record for every validated seam so the caller can
  /// splice in the underlying `-ः` on the LEFT and the corresponding
  /// independent vowel on the RIGHT.
  List<_VisargaSeam> _findVisargaSeams(String token) {
    final List<_VisargaSeam> seams = <_VisargaSeam>[];
    final int n = token.length;
    if (n < 4) return seams;
    // Akshara boundaries are needed to gate form (b) to real
    // word-shape seams (a `र + ा` that's part of a conjunct like
    // `र्तार` shouldn't split).
    final Set<int> boundarySet = _aksharaBoundaries(token).toSet();
    int i = 1;
    while (i < n - 1) {
      final int cv = token.codeUnitAt(i);
      if (cv != 0x0930 && cv != 0x0936 && cv != 0x0937 && cv != 0x0938) {
        i++;
        continue;
      }
      final int next = token.codeUnitAt(i + 1);
      _VisargaSeam? seam;
      if (next == _viramaCU && i + 2 < n) {
        // Form (a): C्<next>
        final int nx2 = token.codeUnitAt(i + 2);
        if (_visargaSurfaceMatches(cv, nx2) &&
            (cv != 0x0930 || _precedingVowelIsNonA(token, i))) {
          seam = _VisargaSeam(i, i + 2, '', cv);
        }
      } else if (cv == 0x0930 &&
          _matraToIndependentVowel.containsKey(next)) {
        // Form (b): र<matra> — the `र` is a visarga-transformed
        // consonant and the matra is the following word's opening
        // vowel written as a matra.
        if (boundarySet.contains(i) && _precedingVowelIsNonA(token, i)) {
          final String indep =
              String.fromCharCode(_matraToIndependentVowel[next]!);
          seam = _VisargaSeam(i, i + 2, indep, cv);
        }
      }
      if (seam == null) {
        i++;
        continue;
      }
      final String leftUnderlying =
          '${token.substring(0, seam.leftEnd)}\u0903';
      if (!_isValidVisargaTail(leftUnderlying, cv)) {
        i++;
        continue;
      }
      seams.add(seam);
      i = seam.rightStart;
    }
    return seams;
  }

  /// True if [leftUnderlying] (which must end in `ः`) matches one of
  /// the visarga endings appropriate to the halant consonant
  /// [halantCons] that formed the surface seam, with a
  /// dictionary-recognised stem. The `-ष्ट/ठ` and `-स्त/थ` surface
  /// patterns use the stricter [_strictVisargaEndings] table because
  /// they clash constantly with intra-word clusters (`आविष्ट`,
  /// `अस्ति`, `कष्ट`, `पश्चात्` — well, that last one is `-श्च`, but
  /// the same class of noise). The stem check accepts a direct dict
  /// hit, or any ≥ 2-akshara tail of the stem being a dict entry
  /// (handles the case where the LEFT of a visarga seam is itself a
  /// compound whose last member is what carries the inflection).
  bool _isValidVisargaTail(String leftUnderlying, int halantCons) {
    final List<(String, int)> endings =
        (halantCons == 0x0937 || halantCons == 0x0938)
            ? _strictVisargaEndings
            : _visargaEndings;
    for (final (String suf, int minStem) in endings) {
      if (!leftUnderlying.endsWith(suf)) continue;
      final int stemLen = leftUnderlying.length - suf.length;
      if (stemLen < minStem) continue;
      final String stem = leftUnderlying.substring(0, stemLen);
      if (_stems.contains(stem)) return true;
      final List<int> b = _aksharaBoundaries(stem);
      // b has length = num_aksharas + 1. Try every non-trivial tail
      // starting at akshara boundary bi > 0.
      for (int bi = 1; bi < b.length - 1; bi++) {
        // Require the tail to be at least 2 aksharas.
        if (b.length - 1 - bi < 2) continue;
        final String tail = stem.substring(b[bi]);
        if (_stems.contains(tail)) return true;
      }
    }
    return false;
  }

  /// True if the vowel of the akshara ending at [visargaConsPos] - 1
  /// is something other than `a` or `ā`. Walks backward past nasal /
  /// visarga / vedic-tone marks so `-ैं` still reads as `ai`. Used to
  /// gate the `-र्` visarga-sandhi rule (which fires only after
  /// non-`a`/`ā` vowels).
  bool _precedingVowelIsNonA(String token, int visargaConsPos) {
    int p = visargaConsPos - 1;
    while (p >= 0) {
      final int c = token.codeUnitAt(p);
      if (c == 0x0901 ||
          c == 0x0902 ||
          c == 0x0903 ||
          (c >= 0x0951 && c <= 0x0957)) {
        p--;
        continue;
      }
      if (c == 0x093E) return false; // ा
      if (c >= 0x093F && c <= 0x094C) return true; // other matras
      return false; // consonant → implicit `a`
    }
    return false;
  }

  /// Fewer pieces beats more; among equal counts, MORE sandhi seams win
  /// (a cover that recognises a real fused-matra seam like `सनक + आदीन्`
  /// at surface `का` beats a chop that just found short 2-akshara literal
  /// matches — `_renderSurfaceSafeSeams` then suppresses the unsafe seam
  /// so the noisy literal cover collapses to a single readable piece).
  /// Among still-equal candidates, longer last piece wins (Sanskrit
  /// compounds are head-final — the last stem carries the head noun);
  /// finally, longer minimum piece wins (avoids balanced-looking splits
  /// like `उद्धवना|रद` beating `उद्धव|नारद`).
  bool _isBetter(_Best a, _Best b) {
    if (a.forms.length != b.forms.length) {
      return a.forms.length < b.forms.length;
    }
    if (a.sandhiSeamCount != b.sandhiSeamCount) {
      return a.sandhiSeamCount > b.sandhiSeamCount;
    }
    if (a.lastPieceAksharas != b.lastPieceAksharas) {
      return a.lastPieceAksharas > b.lastPieceAksharas;
    }
    return a.minPieceAksharas > b.minPieceAksharas;
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

/// A single visarga-sandhi seam detected by
/// [DevanagariSegmenter._findVisargaSeams]. The seam splits [token]
/// into a LEFT part `token[.. leftEnd]` (to which the caller appends
/// `-ः` to recover the underlying form) and a RIGHT part
/// `rightPrepend + token[rightStart ..]` (where [rightPrepend] carries
/// the RIGHT word's opening independent vowel when the surface had
/// absorbed it as a matra on the visarga-transformed consonant).
class _VisargaSeam {
  const _VisargaSeam(
      this.leftEnd, this.rightStart, this.rightPrepend, this.halantCons);

  final int leftEnd;
  final int rightStart;
  final String rightPrepend;
  final int halantCons;
}

class _Best {
  const _Best(this.forms, this.endBoundaries, this.tailStates,
      this.lastPieceAksharas, this.minPieceAksharas, this.sandhiSeamCount);

  /// Dictionary/underlying form of each piece — what actually gets emitted
  /// between ZWSes. In literal mode this equals the surface substring; in
  /// sandhi mode it may differ (e.g. surface `नियमा` → underlying `नियम`).
  final List<String> forms;

  /// Akshara-index at which each piece ends (parallel to [forms]). Used
  /// by the surface-safe sandhi rescue to map DP piece boundaries back
  /// to surface positions.
  final List<int> endBoundaries;

  /// Tail state of each piece (parallel to [forms]) — 0 literal, 1 or 2
  /// sandhi-undone. The seam *after* piece `i` is surface-safe iff
  /// `tailStates[i] == 0`.
  final List<int> tailStates;

  /// Length in aksharas of the last piece — used as the tie-breaker.
  final int lastPieceAksharas;

  /// Length in aksharas of the *shortest* piece so far. Used as a third-
  /// tier tiebreak: given equal piece count and equal last-piece length,
  /// we prefer the more balanced segmentation, since compounds like
  /// `उद्धवना|रद|हृदय|विलासम्` (min = 2 aksharas) are almost always
  /// wrong readings of `उद्धव|नारद|हृदय|विलासम्` (min = 3 aksharas).
  final int minPieceAksharas;

  /// Count of pieces with a non-zero `tailState` — i.e. how many seams
  /// this cover interprets as a fused matra rather than a literal seam.
  /// Used as the final tiebreak (see [DevanagariSegmenter._isBetter]).
  final int sandhiSeamCount;
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
    case 0x0923: // ण + ट-vagas (or ANY cluster) — all impossible
      return true;
    case 0x0928: // न + tavarga
      return c2 >= 0x0924 && c2 <= 0x0927;
    case 0x092E: // म + pavarga
      return c2 >= 0x092A && c2 <= 0x092D;
    default:
      return false;
  }
}
