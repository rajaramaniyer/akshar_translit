/// The scripts supported by this package.
enum Script {
  /// Devanagari as used for Sanskrit. Alias-scripts [marathi] and [hindi]
  /// share the same glyph inventory but disable Sanskrit-specific processing
  /// (currently: the compound splitter).
  devanagari,

  /// Devanagari as used for Marathi. Same character inventory as
  /// [devanagari]; distinct only so that Sanskrit-specific pre-processing
  /// (e.g. the compound splitter) is skipped. Marathi ↔ Devanagari ↔ Hindi
  /// pairs are byte-for-byte identity.
  marathi,

  /// Devanagari as used for Hindi. Same character inventory as
  /// [devanagari]; distinct only so that Sanskrit-specific pre-processing
  /// (e.g. the compound splitter) is skipped. Hindi ↔ Devanagari ↔ Marathi
  /// pairs are byte-for-byte identity.
  hindi,

  /// Tamil, including Grantha letters that are part of the Tamil Unicode
  /// block (ஜ ஶ ஷ ஸ ஹ) and superscript-digit annotations (² ³ ⁴) that
  /// distinguish Sanskrit consonant classes.
  tamil,

  /// Kannada.
  kannada,

  /// Telugu.
  telugu,

  /// Malayalam.
  malayalam,

  /// ITRANS Roman (ASCII, case-sensitive).
  itrans,

  /// Phonetic English (a.k.a. Aksharamukha's `RomanColloquial`). No
  /// diacritics or escape characters — designed for casual readers, so
  /// distinctions between retroflex/dental and short/long vowels collapse.
  romanReadable,
}
