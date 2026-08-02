# akshar_translit

Offline Sanskrit/Tamil → Kannada/Telugu/Malayalam/Tamil/Devanagari/Roman
transliteration for Flutter and Dart. Rule tables are ported from
[Aksharamukha](https://github.com/virtualvinodh/aksharamukha-python) (MIT).

## Supported scripts

- **Sources:** Devanagari (Sanskrit, Hindi, etc.), Tamil (with Grantha
  extensions and superscript `² ³ ⁴` markers for Sanskrit distinctions)
- **Targets:** Devanagari, Tamil, Kannada, Telugu, Malayalam, ITRANS,
  RomanReadable

`RomanReadable` is a phonetic-English target designed for casual readers
(`कृष्ण` → `krishna`, `गङ्गा` → `ganga`, `संस्कृतम्` → `samskritam`).
Diacritics and retroflex/dental distinctions collapse; use `ITRANS` if you
need those preserved.

## Usage

```yaml
dependencies:
  akshar_translit:
    path: ../akshar_translit   # or git: / hosted, per your workflow
```

```dart
import 'package:akshar_translit/akshar_translit.dart';

void main() {
  print(transliterate('रामायणम्',
      from: Script.devanagari, to: Script.kannada));         // ರಾಮಾಯಣಂ
  print(transliterate('कृष्ण',
      from: Script.devanagari, to: Script.romanReadable));   // krishna
  print(transliterate('கீதா',
      from: Script.tamil, to: Script.romanReadable));        // gita
}
```

For repeated calls, reuse a `Transliterator` — it's a const object so this
is essentially free either way:

```dart
const t = Transliterator();
t.convert('गङ्गा', from: Script.devanagari, to: Script.itrans); // gaN^gA
```

## Word-break hint (`\u200B`)

Long Sanskrit compounds are hard to read once transliterated — they can
look like passwords. To let content authors control readability without
changing the source display, insert a **Zero-Width Space** (`\u200B`,
ZWSP) at the desired word boundaries in the source. It renders as zero
width in Devanagari/Tamil display, but transliteration promotes it to a
real space in every target.

```dart
final source = 'राम\u200Bसीता';    // looks like 'रामसीता' on screen
transliterate(source, from: Script.devanagari, to: Script.kannada);
// → 'ರಾಮ ಸೀತಾ'  (space appears)
transliterate(source, from: Script.devanagari, to: Script.romanReadable);
// → 'rama sita'
```

Suggested authoring workflow: write with regular spaces during editing,
then run a one-time pass that converts spaces to `\u200B` before storing
to the database. The source stays visually tight for traditionalists; the
transliterated output stays readable for everyone else.

## Options

`TransliterationOptions` mirrors the common Aksharamukha post-options.
Each is a nullable `bool` — pass `null` (the default) to use
Aksharamukha's per-target default, or override explicitly.

- `nasalToAnusvara` — nasal + virama + class-consonant → anusvara + consonant
- `anusvaraToNasal` — inverse of the above (non-nukta)
- `mToAnusvara` — word-final `m` + virama → anusvara
- `malayalamAnusvaraNasal` — Malayalam's asymmetric traditional expansion
- `malayalamRemoveHistorical` — collapse historical Malayalam letters
- `teluguRemoveShortEO` — drop Telugu short e/o length markers
- `removeVedicSvaras` — strip Vedic accent marks (non-null; default `true`)

## Known limitations

- **Tamil source with no Grantha markers** cannot recover Sanskrit
  distinctions (aspirated/voiced/vocalic ṛ). `கிருஷ்ண` → `kirushna`,
  not `krishna`. Add superscript markers (`² ³ ⁴`) in the source where
  needed.
- **ऋ always romanises as `ri`** (`kri` — north-Indian convention). If
  you need the south-Indian `kru`, it needs custom post-processing.
- **Word-final schwa is not dropped.** `राम` → `rama`, not `ram`.
- **No sandhi splitting.** `रामसीता` (no ZWSP) → `ramasita`; the
  transliterator won't guess word boundaries.

## Attribution

Rule data © Vinodh Rajan, MIT-licensed. See `ATTRIBUTION.md` and `LICENSE`.

## Testing

Requires Dart SDK 3.0+ or Flutter SDK:

```
dart pub get
dart test
```
