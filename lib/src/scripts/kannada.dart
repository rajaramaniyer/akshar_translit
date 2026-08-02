// Ported from aksharamukha/ScriptMap/MainIndic/Kannada.py

import '../script.dart';
import '../script_map.dart';

const ScriptMap map = ScriptMap(
  id: Script.kannada,
  vowels: <String>[
    '\u0C85', '\u0C86', '\u0C87', '\u0C88', '\u0C89',
    '\u0C8A', '\u0C8B', '\u0CE0', '\u0C8C', '\u0CE1',
    '\u0C8F', '\u0C90', '\u0C93', '\u0C94',
  ],
  southVowels: <String>['\u0C8E', '\u0C92'],
  modernVowels: <String>['\u0C8E\u02BC', '\u0C86\u02BC'],
  sinhalaVowels: <String>['\u0C8F\u02C7'],
  vowelSigns: <String>[
    '\u0CBE', '\u0CBF', '\u0CC0', '\u0CC1', '\u0CC2',
    '\u0CC3', '\u0CC4', '\u0CE2', '\u0CE3',
    '\u0CC7', '\u0CC8', '\u0CCB', '\u0CCC',
  ],
  southVowelSigns: <String>['\u0CC6', '\u0CCA'],
  modernVowelSigns: <String>['\u0CC6\u02BC', '\u0CBE\u02BC'],
  sinhalaVowelSigns: <String>['\u0CC7\u02C7'],
  ayogavahas: <String>['\u0C81', '\u0C82', '\u0C83'],
  viramas: <String>['\u0CCD'],
  consonants: <String>[
    '\u0C95', '\u0C96', '\u0C97', '\u0C98', '\u0C99',
    '\u0C9A', '\u0C9B', '\u0C9C', '\u0C9D', '\u0C9E',
    '\u0C9F', '\u0CA0', '\u0CA1', '\u0CA2', '\u0CA3',
    '\u0CA4', '\u0CA5', '\u0CA6', '\u0CA7', '\u0CA8',
    '\u0CAA', '\u0CAB', '\u0CAC', '\u0CAD', '\u0CAE',
    '\u0CAF', '\u0CB0', '\u0CB2', '\u0CB5',
    '\u0CB6', '\u0CB7', '\u0CB8', '\u0CB9',
  ],
  southConsonants: <String>['\u0CB3', '\u0CDE', '\u0CB1', '\u0CA8\u0CBC'],
  nuktaConsonants: <String>[
    '\u0C95\u0CBC', '\u0C96\u0CBC', '\u0C97\u0CBC', '\u0C9C\u0CBC',
    '\u0CA1\u0CBC', '\u0CA2\u0CBC', '\u0CAB\u0CBC', '\u0CAF\u0CBC',
  ],
  sinhalaConsonants: <String>[
    '\u0C82\u02C6\u0C97',
    '\u0C82\u02C6\u0C9C',
    '\u0C82\u02C6\u0CA1',
    '\u0C82\u02C6\u0CA6',
    '\u0C82\u02C6\u0CAC',
  ],
  nuktas: <String>['\u0CBC'],
  om: <String>['\u0C93\u0C82'],
  signs: <String>['\u0CBD', '\u0964', '\u0965'],
  aytham: <String>['\u0C83\u02BC'],
  numerals: <String>[
    '\u0CE6', '\u0CE7', '\u0CE8', '\u0CE9', '\u0CEA',
    '\u0CEB', '\u0CEC', '\u0CED', '\u0CEE', '\u0CEF',
  ],
);
