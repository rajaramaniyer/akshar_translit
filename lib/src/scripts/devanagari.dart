// Ported from aksharamukha/ScriptMap/MainIndic/Devanagari.py
// See ATTRIBUTION.md.

import '../script.dart';
import '../script_map.dart';

const ScriptMap map = ScriptMap(
  id: Script.devanagari,
  vowels: <String>[
    '\u0905', '\u0906', '\u0907', '\u0908', '\u0909', // a ā i ī u
    '\u090A', '\u090B', '\u0960', '\u090C', '\u0961', // ū ṛ ṝ ḷ ḹ
    '\u090F', '\u0910', '\u0913', '\u0914', // e ai o au
  ],
  southVowels: <String>['\u090E', '\u0912'], // ĕ ŏ
  modernVowels: <String>['\u090D', '\u0911'], // candra e, candra o
  sinhalaVowels: <String>['एॕ'],
  vowelSigns: <String>[
    '\u093E', '\u093F', '\u0940', '\u0941', '\u0942', // -ā -i -ī -u -ū
    '\u0943', '\u0944', '\u0962', '\u0963', // -ṛ -ṝ -ḷ -ḹ
    '\u0947', '\u0948', '\u094B', '\u094C', // -e -ai -o -au
  ],
  southVowelSigns: <String>['\u0946', '\u094A'],
  modernVowelSigns: <String>['\u0945', '\u0949'],
  sinhalaVowelSigns: <String>['ॕ'],
  ayogavahas: <String>['\u0901', '\u0902', '\u0903'], // ̐ ṁ ḥ
  viramas: <String>['\u094D'],
  consonants: <String>[
    '\u0915', '\u0916', '\u0917', '\u0918', '\u0919', // k kh g gh ṅ
    '\u091A', '\u091B', '\u091C', '\u091D', '\u091E', // c ch j jh ñ
    '\u091F', '\u0920', '\u0921', '\u0922', '\u0923', // ṭ ṭh ḍ ḍh ṇ
    '\u0924', '\u0925', '\u0926', '\u0927', '\u0928', // t th d dh n
    '\u092A', '\u092B', '\u092C', '\u092D', '\u092E', // p ph b bh m
    '\u092F', '\u0930', '\u0932', '\u0935', //           y r l v
    '\u0936', '\u0937', '\u0938', '\u0939', //           ś ṣ s h
  ],
  southConsonants: <String>['\u0933', '\u0934', '\u0931', '\u0929'],
  nuktaConsonants: <String>[
    '\u0958', '\u0959', '\u095A', '\u095B',
    '\u095C', '\u095D', '\u095E', '\u095F',
  ],
  sinhalaConsonants: <String>[
    '\u0901\u02C6\u0917',
    '\u0901\u02C6\u091C',
    '\u0901\u02C6\u0921',
    '\u0901\u02C6\u0926',
    '\u0901\u02C6\u092C',
  ],
  nuktas: <String>['\u093C'],
  om: <String>['\u0950'],
  signs: <String>['\u093D', '\u0964', '\u0965'], // avagraha, danda, ‖
  aytham: <String>['\u0903\u02BC'],
  numerals: <String>[
    '\u0966', '\u0967', '\u0968', '\u0969', '\u096A',
    '\u096B', '\u096C', '\u096D', '\u096E', '\u096F',
  ],
);
