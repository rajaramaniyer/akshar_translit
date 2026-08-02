// Ported from aksharamukha/ScriptMap/Roman/Itrans.py
//
// The `\u00D7` (×) in [viramas] is not part of the ITRANS spec — it is an
// internal marker used during Indic→Roman conversion and stripped by
// [FixRomanOutput].

import '../script.dart';
import '../script_map.dart';

const ScriptMap map = ScriptMap(
  id: Script.itrans,
  vowels: <String>[
    'a', 'A', 'i', 'I', 'u',
    'U', 'R^i', 'R^I', 'L^i', 'L^I',
    'e', 'ai', 'o', 'au',
  ],
  southVowels: <String>['^e', '^o'],
  modernVowels: <String>['e.c', 'A.c'],
  sinhalaVowels: <String>['a.C'],
  // In ITRANS, vowel signs share glyph forms with independent vowels except
  // 'a' (which is implicit after every consonant).
  vowelSigns: <String>[
    'A', 'i', 'I', 'u', 'U',
    'R^i', 'R^I', 'L^i', 'L^I',
    'e', 'ai', 'o', 'au',
  ],
  southVowelSigns: <String>['^e', '^o'],
  modernVowelSigns: <String>['e.c', 'A.c'],
  sinhalaVowelSigns: <String>['a.C'],
  ayogavahas: <String>['.N', 'M', 'H'],
  viramas: <String>['\u00D7'], // internal-only marker
  consonants: <String>[
    'k', 'kh', 'g', 'gh', '~N',
    'ch', 'Ch', 'j', 'jh', '~n',
    'T', 'Th', 'D', 'Dh', 'N',
    't', 'th', 'd', 'dh', 'n',
    'p', 'ph', 'b', 'bh', 'm',
    'y', 'r', 'l', 'v',
    'sh', 'Sh', 's', 'h',
  ],
  southConsonants: <String>['L', 'zh', 'R', '^n'],
  nuktaConsonants: <String>[
    'q', 'K', 'G', 'z',
    '.D', '.Dh', 'f', 'Y',
  ],
  sinhalaConsonants: <String>['n*g', 'n*j', 'n*D', 'n*d', 'm*b'],
  nuktas: <String>['Q'],
  om: <String>['oM'],
  signs: <String>['.a', '.', '..'],
  aytham: <String>['K^'],
  numerals: <String>['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
);
