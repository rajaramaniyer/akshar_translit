import 'package:akshar_translit/akshar_translit.dart';
import 'package:test/test.dart';

const String _zwsp = '\u200B';

void main() {
  final DevanagariSegmenter seg = DevanagariSegmenter.bundled();

  group('DevanagariSegmenter.insertBreaks', () {
    test('splits a plain two-stem compound', () {
      // aMSakaraRa = aMSa + karaRa (both in csl-inflect)
      expect(seg.insertBreaks('अंशकरण'), 'अंश${_zwsp}करण');
    });

    test('splits a three-stem compound', () {
      // dharma-kzetra-pati (all three are common MW stems)
      expect(seg.insertBreaks('धर्मक्षेत्रपति'),
          'धर्म${_zwsp}क्षेत्र${_zwsp}पति');
    });

    test('leaves a single known stem alone', () {
      expect(seg.insertBreaks('राम'), 'राम');
      expect(seg.insertBreaks('धर्म'), 'धर्म');
    });

    test('leaves an unrecognisable form unchanged', () {
      // A made-up sequence that isn't a valid concat of stems.
      expect(seg.insertBreaks('क्षक्षक्ष'), 'क्षक्षक्ष');
    });

    test('preserves non-Devanagari runs and whitespace', () {
      expect(
        seg.insertBreaks('अंशकरण, धर्मक्षेत्र!'),
        'अंश${_zwsp}करण, धर्म${_zwsp}क्षेत्र!',
      );
    });

    test('never splits inside a virama cluster', () {
      // क्ष is a single akshara — must not be broken between क् and ष.
      final String out = seg.insertBreaks('क्षत्रिय');
      expect(out.contains('क्$_zwsp'), isFalse);
      expect(out.contains('क्$_zwsp'), isFalse);
    });
  });

  group('Transliterator.splitCompounds option', () {
    const TransliterationOptions splitOn =
        TransliterationOptions(splitCompounds: true);
    const TransliterationOptions splitOff = TransliterationOptions();

    test('off by default: compound comes through joined', () {
      final String out = transliterate('अंशकरण',
          from: Script.devanagari, to: Script.itrans);
      // ITRANS output should be a single run without spaces.
      expect(out.contains(' '), isFalse);
    });

    test('on: ZWS becomes a space in Roman targets', () {
      final String out = transliterate('अंशकरण',
          from: Script.devanagari, to: Script.itrans, options: splitOn);
      expect(out.contains(' '), isTrue);
      // and the pieces are still there
      expect(out.replaceAll(' ', ''),
          transliterate('अंशकरण',
              from: Script.devanagari, to: Script.itrans, options: splitOff));
    });

    test('on: ZWS survives into an Indic target', () {
      final String out = transliterate('धर्मक्षेत्रपति',
          from: Script.devanagari, to: Script.kannada, options: splitOn);
      // ZWS in Indic-to-Indic is emitted as a real space (see Transliterator).
      expect(out.contains(' '), isTrue);
    });

    test('on: non-Devanagari source is left alone by the segmenter', () {
      // Tamil compound that happens to have Devanagari-like structure.
      // Should transliterate normally, no spaces added.
      const String tam = 'கமலம்';
      final String out = transliterate(tam,
          from: Script.tamil, to: Script.itrans, options: splitOn);
      expect(out.contains(' '), isFalse);
    });
  });
}
