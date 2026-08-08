/// User-tunable knobs applied on top of each target's built-in defaults.
///
/// Each option is nullable so `null` means "use the target default". Set
/// `true`/`false` to force the behaviour on or off regardless of target.
class TransliterationOptions {
  const TransliterationOptions({
    this.nasalToAnusvara,
    this.anusvaraToNasal,
    this.mToAnusvara,
    this.malayalamAnusvaraNasal,
    this.malayalamRemoveHistorical,
    this.teluguRemoveShortEO,
    this.tamilRemoveApostrophe,
    this.removeVedicSvaras = false,
    this.useNativeNumerals = false,
    this.splitCompounds = false,
  });

  /// Rewrite class nasal + virama + class consonant (ङ्क, ञ्च, ण्ट, न्त, म्प) as
  /// anusvara + consonant. Default `true` for Kannada, Telugu. Ignored for
  /// Roman targets.
  final bool? nasalToAnusvara;

  /// Reverse of [nasalToAnusvara]: expand anusvara to a class nasal when a
  /// class consonant follows. Default `true` for Malayalam via
  /// [malayalamAnusvaraNasal]; off elsewhere.
  final bool? anusvaraToNasal;

  /// Rewrite trailing `म्` (Devanagari `m` + virama) and its equivalents in
  /// other Brahmi scripts as anusvara when not followed by a consonant.
  /// Default `true` for Kannada, Telugu, Malayalam.
  final bool? mToAnusvara;

  /// Malayalam-specific anusvara → nasal rule (traditional orthography).
  /// Default `true` for Malayalam.
  final bool? malayalamAnusvaraNasal;

  /// Replace archaic chillu-n `ഩ` with `ന`. Default `true` for Malayalam.
  final bool? malayalamRemoveHistorical;

  /// Drop Aksharamukha's short-e/short-o placeholder (U+0952 + ZWSP) from
  /// Telugu output — Telugu shows short and long e/o with the same base
  /// glyph. Default `true` for Telugu.
  final bool? teluguRemoveShortEO;

  /// Strip the modifier-letter apostrophes (`ʼ`, `ˮ`) that Aksharamukha
  /// sprinkles into Tamil output to mark Sanskrit-specific sounds
  /// (`ருʼ` for ṛ, `ம்ʼ` for anusvara, etc.). Default `true` for
  /// Tamil — the marks are usually noise for readers who don't need the
  /// Sanskrit distinction.
  final bool? tamilRemoveApostrophe;

  /// Strip Vedic tonal marks (udatta, anudatta, dvi-svarita) from the input
  /// before conversion.
  final bool removeVedicSvaras;

  /// When `false` (the default) native-script digits in the output are
  /// flattened to ASCII `0`–`9` — matching the way most modern Indian
  /// content is typeset. Set to `true` to preserve target-native digits
  /// (Devanagari `०–९`, Tamil `௦–௯`, etc.), matching Aksharamukha's
  /// upstream behaviour. Roman targets are unaffected either way.
  final bool useNativeNumerals;

  /// When `true` and the source is Devanagari, run a dictionary-driven
  /// compound splitter over each token before transliteration and insert
  /// U+200B between recognised stems. The splitter is literal (no sandhi
  /// undo): a compound is split only when its surface form equals the
  /// concatenation of two or more stems from the bundled csl-inflect stem
  /// set. Tokens that don't fully segment pass through unchanged. Ignored
  /// when the source isn't Devanagari.
  final bool splitCompounds;
}
