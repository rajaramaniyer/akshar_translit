// Ported from aksharamukha/ScriptMap/Roman/RomanColloquial.py
//
// This is Aksharamukha's `RomanColloquial` scheme (not its `RomanReadable`
// which retains apostrophes like `kri'shna`). We surface it under the
// friendlier `Script.romanReadable` name — the enum wording is closer to
// what most users want.
//
// Retroflex/dental and short/long vowels collapse in this scheme. That is
// intentional: it's meant for casual reading, not scholarly transliteration.
// The `\u00D7` (×) in [viramas] is an internal marker used during
// Indic→Roman conversion and stripped by [FixRomanOutput].

import '../script.dart';
import '../script_map.dart';

const ScriptMap map = ScriptMap(
  id: Script.romanReadable,
  vowels: <String>[
    'a', 'a', 'i', 'i', 'u',
    'u', 'ri', 'ri', 'li', 'li',
    'e', 'ai', 'o', 'au',
  ],
  southVowels: <String>['e', 'o'],
  modernVowels: <String>['a', 'o'],
  sinhalaVowels: <String>['e'],
  vowelSigns: <String>[
    'a', 'i', 'i', 'u', 'u',
    'ri', 'ri', 'li', 'li',
    'e', 'ai', 'o', 'au',
  ],
  southVowelSigns: <String>['e', 'o'],
  modernVowelSigns: <String>['a', 'o'],
  sinhalaVowelSigns: <String>['e'],
  ayogavahas: <String>['M', 'M', 'h'],
  viramas: <String>['\u00D7'], // internal-only marker
  consonants: <String>[
    'k', 'kh', 'g', 'gh', 'ng',
    'ch', 'chh', 'j', 'jh', 'nj',
    "t'", "th", "d'", "dh", 'n',
    't', 'th', 'd', 'dh', 'n',
    'p', 'ph', 'b', 'bh', 'm',
    'y', 'r', 'l', 'v',
    'sh', 'sh', 's', 'h',
  ],
  southConsonants: <String>['l', 'zh', 'r', 'n'],
  nuktaConsonants: <String>[
    'q', 'kh', 'g', 'z',
    "r'", "r'h", 'f', 'y',
  ],
  sinhalaConsonants: <String>['ng', 'nj', 'nd', 'nd', 'mb'],
  nuktas: <String>['\u02BD\u02BD'],
  om: <String>['Om'],
  signs: <String>["'", '.', '..'],
  aytham: <String>['g'],
  numerals: <String>['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
);
