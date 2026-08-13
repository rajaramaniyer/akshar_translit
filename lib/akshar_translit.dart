/// Offline transliteration of Sanskrit (Devanagari) and Tamil text to
/// Kannada, Telugu, Malayalam, and ITRANS Roman.
///
/// ```dart
/// import 'package:akshar_translit/akshar_translit.dart';
///
/// final String out = transliterate(
///   'गङ्गा',
///   from: Script.devanagari,
///   to: Script.kannada,
/// ); // ಗಂಗಾ
/// ```
library;

import 'src/options.dart';
import 'src/script.dart';
import 'src/transliterator.dart';

export 'src/options.dart' show TransliterationOptions;
export 'src/script.dart' show Script;
export 'src/transliterator.dart' show Transliterator;
export 'src/segmenter/segmenter.dart' show DevanagariSegmenter;

/// Convenience wrapper around [Transliterator.convert].
String transliterate(
  String input, {
  required Script from,
  required Script to,
  TransliterationOptions options = const TransliterationOptions(),
}) =>
    const Transliterator().convert(input, from: from, to: to, options: options);
