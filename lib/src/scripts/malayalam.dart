// Ported from aksharamukha/ScriptMap/MainIndic/Malayalam.py

import '../script.dart';
import '../script_map.dart';

const ScriptMap map = ScriptMap(
  id: Script.malayalam,
  vowels: <String>[
    '\u0D05', '\u0D06', '\u0D07', '\u0D08', '\u0D09',
    '\u0D0A', '\u0D0B', '\u0D60', '\u0D0C', '\u0D61',
    '\u0D0F', '\u0D10', '\u0D13', '\u0D14',
  ],
  southVowels: <String>['\u0D0E', '\u0D12'],
  modernVowels: <String>['\u0D0E\u02BC', '\u0D06\u02BC'],
  sinhalaVowels: <String>['\u0D0F\u02C7'],
  vowelSigns: <String>[
    '\u0D3E', '\u0D3F', '\u0D40', '\u0D41', '\u0D42',
    '\u0D43', '\u0D44', '\u0D62', '\u0D63',
    '\u0D47', '\u0D48', '\u0D4B', '\u0D57',
  ],
  southVowelSigns: <String>['\u0D46', '\u0D4A'],
  modernVowelSigns: <String>['\u0D46\u02BC', '\u0D3E\u02BC'],
  sinhalaVowelSigns: <String>['\u0D47\u02C7'],
  ayogavahas: <String>['\u0D01', '\u0D02', '\u0D03'],
  viramas: <String>['\u0D4D'],
  consonants: <String>[
    '\u0D15', '\u0D16', '\u0D17', '\u0D18', '\u0D19',
    '\u0D1A', '\u0D1B', '\u0D1C', '\u0D1D', '\u0D1E',
    '\u0D1F', '\u0D20', '\u0D21', '\u0D22', '\u0D23',
    '\u0D24', '\u0D25', '\u0D26', '\u0D27', '\u0D28',
    '\u0D2A', '\u0D2B', '\u0D2C', '\u0D2D', '\u0D2E',
    '\u0D2F', '\u0D30', '\u0D32', '\u0D35',
    '\u0D36', '\u0D37', '\u0D38', '\u0D39',
  ],
  southConsonants: <String>['\u0D33', '\u0D34', '\u0D31', '\u0D29'],
  nuktaConsonants: <String>[
    '\u0D15\u00B7', '\u0D16\u00B7', '\u0D17\u00B7', '\u0D1C\u00B7',
    '\u0D21\u00B7', '\u0D22\u00B7', '\u0D2B\u00B7', '\u0D2F\u00B7',
  ],
  sinhalaConsonants: <String>[
    '\u0D02\u02C6\u0D17',
    '\u0D02\u02C6\u0D1C',
    '\u0D02\u02C6\u0D21',
    '\u0D02\u02C6\u0D26',
    '\u0D02\u02C6\u0D2C',
  ],
  nuktas: <String>['\u00B7'],
  om: <String>['\u0BD0'],
  signs: <String>['\u0D3D', '.', '..'],
  aytham: <String>['\u0B83'],
  numerals: <String>[
    '\u0D66', '\u0D67', '\u0D68', '\u0D69', '\u0D6A',
    '\u0D6B', '\u0D6C', '\u0D6D', '\u0D6E', '\u0D6F',
  ],
);
