/// The scripts supported by this package.
enum Script {
  /// Devanagari (used by Sanskrit, Hindi, Marathi, etc.).
  devanagari,

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
}
