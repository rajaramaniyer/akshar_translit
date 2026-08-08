import 'package:akshar_translit/akshar_translit.dart';

void main() {
  const TransliterationOptions opts =
      TransliterationOptions(splitCompounds: true);

  const List<String> samples = <String>[
    // Yoga-sutra 2.29 — last piece inflected (samADayaH):
    'यमनियमासनप्राणायामप्रत्याहारधारणाध्यानसमाधयः',
    // Same compound with a bare-stem tail (samADi):
    'यमनियमासनप्राणायामप्रत्याहारधारणाध्यानसमाधि',
    // Gita 1.1 — dharmakṣetre kurukṣetre:
    'धर्मक्षेत्रे',
    'कुरुक्षेत्रे',
    // Ramayana chapter word: rAmalakSmaRa
    'रामलक्ष्मण',
    // Mahābhārata word:
    'महाभारत',
    // Classical compound: rAjakumAra
    'राजकुमार',
    // 4-piece: dharmakSetrakurukSetra (both parts bare)
    'धर्मक्षेत्रकुरुक्षेत्र',
  ];

  for (final String s in samples) {
    final String split = DevanagariSegmenter.bundled().insertBreaks(s);
    final String changed = split == s ? '(unchanged)' : split;
    final String itrans = transliterate(s,
        from: Script.devanagari, to: Script.itrans, options: opts);
    print('  in  : $s');
    print('  seg : $changed');
    print('  itr : $itrans');
    print('');
  }
}

