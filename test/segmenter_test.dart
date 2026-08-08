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

  group('DevanagariSegmenter.insertBreaks (allowVowelSandhi)', () {
    test('literal mode: vowel-fused compound stays unsplit', () {
      // yamaniyamAsanaprANAyAma...samAdhi — inner seams have fused matras,
      // so nothing here can be recovered without sandhi undo.
      const String yog =
          'यमनियमासनप्राणायामप्रत्याहारधारणाध्यानसमाधि';
      expect(seg.insertBreaks(yog), yog);
    });

    test('sandhi mode: splits at a + a = ā seam (yoga-sūtra compound)', () {
      const String yog =
          'यमनियमासनप्राणायामप्रत्याहारधारणाध्यानसमाधि';
      final String out = seg.insertBreaks(yog, allowVowelSandhi: true);
      // Long-vowel head preferred, so we expect āsana not asana.
      expect(out, contains('आसन'));
      expect(out.split(_zwsp).length, greaterThanOrEqualTo(3));
      // Last piece must be the bare-stem tail samAdhi.
      expect(out.split(_zwsp).last, 'समाधि');
    });

    test('sandhi mode: pass-through when the whole word is a known stem', () {
      // maheśvara is itself in the lexicon — sandhi mode should not force a
      // split of a known headword.
      expect(seg.insertBreaks('महेश्वर', allowVowelSandhi: true), 'महेश्वर');
      expect(seg.insertBreaks('महोत्सव', allowVowelSandhi: true), 'महोत्सव');
    });

    test('sandhi mode: still splits literal (non-fused) seams', () {
      // Consonant-boundary compounds continue to split as they did in
      // literal mode.
      expect(seg.insertBreaks('अंशकरण', allowVowelSandhi: true),
          'अंश${_zwsp}करण');
      expect(seg.insertBreaks('धर्मक्षेत्रपति', allowVowelSandhi: true),
          'धर्म${_zwsp}क्षेत्र${_zwsp}पति');
    });
  });

  group('Transliterator.splitAcrossVowelSandhi option', () {
    const TransliterationOptions sandhiOn = TransliterationOptions(
      splitCompounds: true,
      splitAcrossVowelSandhi: true,
    );
    const TransliterationOptions litOnly =
        TransliterationOptions(splitCompounds: true);

    test('sandhi off: yoga-sūtra compound survives as one run', () {
      final String out = transliterate(
        'यमनियमासनप्राणायामप्रत्याहारधारणाध्यानसमाधि',
        from: Script.devanagari,
        to: Script.itrans,
        options: litOnly,
      );
      expect(out.contains(' '), isFalse);
    });

    test('sandhi on: same compound reads with word breaks in ITRANS', () {
      final String out = transliterate(
        'यमनियमासनप्राणायामप्रत्याहारधारणाध्यानसमाधि',
        from: Script.devanagari,
        to: Script.itrans,
        options: sandhiOn,
      );
      // Must contain word-break spaces.
      expect(out.contains(' '), isTrue);
      // Head-final: last space-separated word is `samAdhi`.
      expect(out.split(' ').last, 'samAdhi');
      // Long-vowel head preferred → we expect the substring `Asana` from आसन.
      expect(out, contains('Asana'));
    });

    test('sandhi on has no effect when splitCompounds is off', () {
      const TransliterationOptions onlySandhi =
          TransliterationOptions(splitAcrossVowelSandhi: true);
      final String out = transliterate(
        'यमनियमासनप्राणायामप्रत्याहारधारणाध्यानसमाधि',
        from: Script.devanagari,
        to: Script.itrans,
        options: onlySandhi,
      );
      expect(out.contains(' '), isFalse);
    });
  });
}
