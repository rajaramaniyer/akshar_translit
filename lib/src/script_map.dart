import 'script.dart';
import 'scripts/devanagari.dart' as dev;
import 'scripts/itrans.dart' as itr;
import 'scripts/kannada.dart' as kan;
import 'scripts/malayalam.dart' as mal;
import 'scripts/roman_readable.dart' as rrd;
import 'scripts/tamil.dart' as tam;
import 'scripts/telugu.dart' as tel;

/// A per-script table of Unicode strings, aligned slot-by-slot with every
/// other [ScriptMap]. Ported from Aksharamukha's `GeneralMap.py` structure.
///
/// Every slot list is fixed-length across scripts, so transliteration reduces
/// to zip-and-replace: whatever appears at index `i` in the source script's
/// list becomes whatever appears at index `i` in the target script's list.
class ScriptMap {
  const ScriptMap({
    required this.id,
    required this.vowels,
    required this.southVowels,
    required this.modernVowels,
    required this.sinhalaVowels,
    required this.vowelSigns,
    required this.southVowelSigns,
    required this.modernVowelSigns,
    required this.sinhalaVowelSigns,
    required this.ayogavahas,
    required this.viramas,
    required this.consonants,
    required this.southConsonants,
    required this.nuktaConsonants,
    required this.sinhalaConsonants,
    required this.nuktas,
    required this.om,
    required this.signs,
    required this.aytham,
    required this.numerals,
  });

  final Script id;

  // Aksharamukha's `Vowels = ['VowelMap', 'SouthVowelMap', 'ModernVowelMap',
  //   'SinhalaVowelMap']`. Concatenated length: 14 + 2 + 2 + 1 = 19.
  final List<String> vowels; // 14: a ā i ī u ū ṛ ṝ ḷ ḹ e ai o au
  final List<String> southVowels; // 2: short e, short o
  final List<String> modernVowels; // 2: candra e, candra o
  final List<String> sinhalaVowels; // 1: æ

  // `VowelSigns = ['ViramaMap', 'VowelSignMap', 'SouthVowelSignMap',
  //   'ModernVowelSignMap', 'SinhalaVowelSignMap']`. Length: 1 + 13 + 2 + 2 + 1
  // = 19. The virama sits at slot 0 so `-a` (implicit vowel) is naturally
  // absent from the sign list.
  final List<String> viramas; // 1
  final List<String> vowelSigns; // 13: -ā -i -ī -u -ū -ṛ -ṝ -ḷ -ḹ -e -ai -o -au
  final List<String> southVowelSigns; // 2
  final List<String> modernVowelSigns; // 2
  final List<String> sinhalaVowelSigns; // 1

  // `CombiningSigns = ['AyogavahaMap', 'NuktaMap']`. Length: 3 + 1 = 4.
  final List<String> ayogavahas; // 3: candrabindu, anusvara, visarga
  final List<String> nuktas; // 1

  // `Consonants = ['ConsonantMap', 'SouthConsonantMap', 'NuktaConsonantMap',
  //   'SinhalaConsonantMap']`. Length: 33 + 4 + 8 + 5 = 50.
  final List<String>
      consonants; // 33: k kh g gh ṅ | c ch j jh ñ | ṭ ṭh ḍ ḍh ṇ | t th d dh n | p ph b bh m | y r l v | ś ṣ s h
  final List<String> southConsonants; // 4: ḷ ḻ ṟ ṉ
  final List<String>
      nuktaConsonants; // 8 (Perso-Arabic): q, ḵ, ġ, z, ṛ, ṛh, f, ẏ
  final List<String> sinhalaConsonants; // 5 Sinhala prenasalised

  final List<String> om; // 1
  final List<String> signs; // 3: avagraha, danda, double-danda
  final List<String> aytham; // 1
  final List<String> numerals; // 10

  /// Concatenation used by Aksharamukha's `ScriptAll` groups, in the same
  /// order the algorithm iterates over. Skipping SinhalaConsonantMap when
  /// building source-side patterns keeps the algorithm predictable — none of
  /// our supported source texts use those forms.
  List<String> get vowelsAll =>
      [...vowels, ...southVowels, ...modernVowels, ...sinhalaVowels];
  List<String> get vowelSignsAll => [
        ...viramas,
        ...vowelSigns,
        ...southVowelSigns,
        ...modernVowelSigns,
        ...sinhalaVowelSigns,
      ];
  List<String> get combiningSignsAll => [...ayogavahas, ...nuktas];
  List<String> get consonantsAll => [
        ...consonants,
        ...southConsonants,
        ...nuktaConsonants,
        ...sinhalaConsonants,
      ];

  static const Map<Script, ScriptMap> _registry = <Script, ScriptMap>{
    Script.devanagari: dev.map,
    Script.tamil: tam.map,
    Script.kannada: kan.map,
    Script.telugu: tel.map,
    Script.malayalam: mal.map,
    Script.itrans: itr.map,
    Script.romanReadable: rrd.map,
  };

  /// Returns the [ScriptMap] for [id].
  static ScriptMap of(Script id) => _registry[id]!;
}
