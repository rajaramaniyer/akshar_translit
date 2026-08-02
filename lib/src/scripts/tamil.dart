// Ported from aksharamukha/ScriptMap/MainIndic/Tamil.py
// Tamil represents Sanskrit consonant classes with superscript digit
// annotations: ka=க, kha=க², ga=க³, gha=க⁴ (etc.). If the source text lacks
// those annotations, the class distinctions cannot be recovered.

import '../script.dart';
import '../script_map.dart';

const ScriptMap map = ScriptMap(
  id: Script.tamil,
  vowels: <String>[
    '\u0B85', '\u0B86', '\u0B87', '\u0B88', '\u0B89', // a ā i ī u
    '\u0B8A',
    '\u0BB0\u0BC1\u02BC', // ū, ṛ (transcribed as ருʼ)
    '\u0BB0\u0BC2\u02BC',
    '\u0BB2\u0BC1\u02BC',
    '\u0BB2\u0BC2\u02BC',
    '\u0B8F', '\u0B90', '\u0B93', '\u0B94', //           e ai o au
  ],
  southVowels: <String>['\u0B8E', '\u0B92'],
  modernVowels: <String>['\u0B8E\u02BC', '\u0B86\u02BC'],
  sinhalaVowels: <String>['\u0B8F\u02C7'],
  vowelSigns: <String>[
    '\u0BBE', '\u0BBF', '\u0BC0', '\u0BC1', '\u0BC2',
    '\u0BCD\u0BB0\u0BC1\u02BC',
    '\u0BCD\u0BB0\u0BC2\u02BC',
    '\u0BCD\u0BB2\u0BC1\u02BC',
    '\u0BCD\u0BB2\u0BC2\u02BC',
    '\u0BC7', '\u0BC8', '\u0BCB', '\u0BCC',
  ],
  southVowelSigns: <String>['\u0BC6', '\u0BCA'],
  modernVowelSigns: <String>['\u0BC6\u02BC', '\u0BBE\u02BC'],
  sinhalaVowelSigns: <String>['\u0BC7\u02C7'],
  ayogavahas: <String>[
    '\u0BAE\u0BCD\u02EE', // candrabindu (approximation via ம்)
    '\u0BAE\u0BCD\u02BC', // anusvara
    '꞉', // visarga (modifier letter colon)
  ],
  viramas: <String>['\u0BCD'],
  consonants: <String>[
    '\u0B95', '\u0B95\u00B2', '\u0B95\u00B3', '\u0B95\u2074', '\u0B99',
    '\u0B9A', '\u0B9A\u00B2', '\u0B9C', '\u0B9C\u00B2', '\u0B9E',
    '\u0B9F', '\u0B9F\u00B2', '\u0B9F\u00B3', '\u0B9F\u2074', '\u0BA3',
    '\u0BA4', '\u0BA4\u00B2', '\u0BA4\u00B3', '\u0BA4\u2074', '\u0BA8',
    '\u0BAA', '\u0BAA\u00B2', '\u0BAA\u00B3', '\u0BAA\u2074', '\u0BAE',
    '\u0BAF', '\u0BB0', '\u0BB2', '\u0BB5',
    '\u0BB6', '\u0BB7', '\u0BB8', '\u0BB9',
  ],
  southConsonants: <String>['\u0BB3', '\u0BB4', '\u0BB1', '\u0BA9'],
  nuktaConsonants: <String>[
    '\u0B83\u02BC\u0B95',
    '\u0B83\u0B95\u00B2',
    '\u0B83\u0B95\u00B3',
    '\u0B83\u0B9C',
    '\u0B83\u0B9F\u00B2',
    '\u0B83\u0B9F\u00B3',
    '\u0B83\u0BAA',
    '\u0B83\u0BAF',
  ],
  sinhalaConsonants: <String>[
    '\u0B99\u0BCD\u02C6\u0B95\u00B3',
    '\u0B9E\u0BCD\u02C6\u0B9C\u00B3',
    '\u0BA3\u0BCD\u02C6\u0B9F\u00B3',
    '\u0BA8\u0BCD\u02C6\u0BA4\u00B3',
    '\u0BAE\u0BCD\u02C6\u0BAA\u00B3',
  ],
  nuktas: <String>['\u00B7'],
  om: <String>['\u0BD0'],
  signs: <String>['(\u0B85)', '\u0964', '\u0965'],
  aytham: <String>['\u0B83'],
  numerals: <String>[
    '\u0BE6', '\u0BE7', '\u0BE8', '\u0BE9', '\u0BEA',
    '\u0BEB', '\u0BEC', '\u0BED', '\u0BEE', '\u0BEF',
  ],
);
