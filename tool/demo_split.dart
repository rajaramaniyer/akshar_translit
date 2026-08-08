import 'package:akshar_translit/akshar_translit.dart';

void main() {
  const TransliterationOptions literal =
      TransliterationOptions(splitCompounds: true);
  const TransliterationOptions sandhi = TransliterationOptions(
    splitCompounds: true,
    splitAcrossVowelSandhi: true,
  );

  const List<String> samples = <String>[
    'यमनियमासनप्राणायामप्रत्याहारधारणाध्यानसमाधयः',
    'यमनियमासनप्राणायामप्रत्याहारधारणाध्यानसमाधि',
    'धर्मक्षेत्रे',
    'कुरुक्षेत्रे',
    'रामलक्ष्मण',
    'महाभारत',
    'राजकुमार',
    'धर्मक्षेत्रकुरुक्षेत्र',
    'महेश्वर',       // mahA + ISvara → maheshvara (a + I → e)
    'महोत्सव',       // mahA + utsava → mahotsava  (a + u → o)
  ];

  final DevanagariSegmenter seg = DevanagariSegmenter.bundled();

  for (final String s in samples) {
    final String segLit = seg.insertBreaks(s);
    final String segSand = seg.insertBreaks(s, allowVowelSandhi: true);
    print('  in     : $s');
    print('  literal: ${segLit == s ? "(unchanged)" : segLit}');
    print('  sandhi : ${segSand == s ? "(unchanged)" : segSand}');
    print('  itr(L) : ${transliterate(s,
        from: Script.devanagari, to: Script.itrans, options: literal)}');
    print('  itr(S) : ${transliterate(s,
        from: Script.devanagari, to: Script.itrans, options: sandhi)}');
    print('');
  }
}


