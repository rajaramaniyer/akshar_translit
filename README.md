# akshar_translit

Offline Sanskrit/Tamil → Kannada/Telugu/Malayalam/ITRANS (Roman) transliteration
for Flutter and Dart. Rule tables are ported from
[Aksharamukha](https://github.com/virtualvinodh/aksharamukha-python) (MIT).

## Supported scripts

- **Sources:** Devanagari (Sanskrit), Tamil (with Grantha extensions)
- **Targets:** Kannada, Telugu, Malayalam, ITRANS (Roman)

## Usage

```yaml
dependencies:
  akshar_translit:
    path: ../akshar_translit   # or git: / hosted, per your workflow
```

```dart
import 'package:akshar_translit/akshar_translit.dart';

void main() {
  final out = transliterate(
    'रामायणम्',
    from: Script.devanagari,
    to: Script.kannada,
  );
  print(out); // ರಾಮಾಯಣಂ
}
```

For repeated calls, reuse a `Transliterator`:

```dart
final t = Transliterator(from: Script.devanagari, to: Script.itrans);
print(t.convert('गङ्गा')); // gaN^gA
```

## Options

`TransliterationOptions` mirrors the common Aksharamukha post-options:

- `nasalToAnusvara` — nasal+virama+class-consonant → anusvara+consonant
- `anusvaraToNasal` — inverse of the above (non-nukta)
- `mToAnusvara` — word-final `m` + virama → anusvara
- `malayalamAnusvaraNasal` — Malayalam-specific asymmetric expansion
- `malayalamRemoveHistorical` — collapse historical Malayalam letters
- `teluguRemoveShortEO` — drop Telugu short e/o markers
- `removeVedicSvaras` — strip Vedic accent marks

Any option left `null` uses Aksharamukha's per-target default.

## Attribution

Rule data © Vinodh Rajan, MIT-licensed. See `ATTRIBUTION.md` and `LICENSE`.

## Testing

Requires Dart SDK 3.0+ or Flutter SDK:

```
dart pub get
dart test
```
