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
    this.removeVedicSvaras = false,
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

  /// Strip Vedic tonal marks (udatta, anudatta, dvi-svarita) from the input
  /// before conversion.
  final bool removeVedicSvaras;
}
