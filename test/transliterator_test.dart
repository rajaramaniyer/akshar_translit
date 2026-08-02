import 'package:akshar_translit/akshar_translit.dart';
import 'package:test/test.dart';

void main() {
  group('Devanagari → Kannada', () {
    test('vowels', () {
      expect(transliterate('अ', from: Script.devanagari, to: Script.kannada), 'ಅ');
      expect(transliterate('आ', from: Script.devanagari, to: Script.kannada), 'ಆ');
      expect(transliterate('ऋ', from: Script.devanagari, to: Script.kannada), 'ಋ');
    });

    test('consonant with implicit a', () {
      expect(transliterate('क', from: Script.devanagari, to: Script.kannada), 'ಕ');
    });

    test('consonant + vowel sign', () {
      expect(transliterate('का', from: Script.devanagari, to: Script.kannada), 'ಕಾ');
      expect(transliterate('कि', from: Script.devanagari, to: Script.kannada), 'ಕಿ');
    });

    test('consonant cluster with virama', () {
      // क + ् + ष
      expect(transliterate('क्ष', from: Script.devanagari, to: Script.kannada), 'ಕ್ಷ');
    });

    test('nasal cluster collapses to anusvara (default option)', () {
      expect(transliterate('गङ्गा', from: Script.devanagari, to: Script.kannada), 'ಗಂಗಾ');
      expect(transliterate('अङ्क', from: Script.devanagari, to: Script.kannada), 'ಅಂಕ');
      expect(transliterate('पञ्च', from: Script.devanagari, to: Script.kannada), 'ಪಂಚ');
    });

    test('trailing m becomes anusvara', () {
      expect(transliterate('रामम्', from: Script.devanagari, to: Script.kannada), 'ರಾಮಂ');
    });

    test('preserve nasal cluster when option is off', () {
      const TransliterationOptions opts =
          TransliterationOptions(nasalToAnusvara: false, mToAnusvara: false);
      expect(
        transliterate('गङ्गा', from: Script.devanagari, to: Script.kannada, options: opts),
        'ಗಙ್ಗಾ',
      );
    });
  });

  group('Devanagari → Telugu', () {
    test('basic word', () {
      expect(transliterate('राम', from: Script.devanagari, to: Script.telugu), 'రామ');
    });

    test('nasal cluster', () {
      expect(transliterate('गङ्गा', from: Script.devanagari, to: Script.telugu), 'గంగా');
    });
  });

  group('Devanagari → Malayalam', () {
    test('basic word', () {
      expect(transliterate('राम', from: Script.devanagari, to: Script.malayalam), 'രാമ');
    });

    test('anusvara before labial expands', () {
      // Malayalam traditional orthography: ം + प → മ്പ
      expect(transliterate('संप', from: Script.devanagari, to: Script.malayalam), 'സമ്പ');
    });

    test('anusvara before non-class consonant stays', () {
      expect(transliterate('संस्कृतम्', from: Script.devanagari, to: Script.malayalam), 'സംസ്കൃതം');
    });
  });

  group('Devanagari → ITRANS', () {
    test('bare consonant', () {
      expect(transliterate('क', from: Script.devanagari, to: Script.itrans), 'ka');
    });

    test('consonant + vowel sign kills implicit a', () {
      expect(transliterate('कि', from: Script.devanagari, to: Script.itrans), 'ki');
      expect(transliterate('का', from: Script.devanagari, to: Script.itrans), 'kA');
    });

    test('virama between consonants (kSha, not kaSha)', () {
      expect(transliterate('क्ष', from: Script.devanagari, to: Script.itrans), 'kSha');
    });

    test('word final halant', () {
      expect(transliterate('राम्', from: Script.devanagari, to: Script.itrans), 'rAm');
    });

    test('anusvara stays as M', () {
      expect(transliterate('गंगा', from: Script.devanagari, to: Script.itrans), 'gaMgA');
    });

    test('classic sanskrit word', () {
      expect(transliterate('गङ्गा', from: Script.devanagari, to: Script.itrans), 'ga~NgA');
    });

    test('visarga', () {
      expect(transliterate('रामः', from: Script.devanagari, to: Script.itrans), 'rAmaH');
    });

    test('om', () {
      expect(transliterate('ॐ', from: Script.devanagari, to: Script.itrans), 'oM');
    });

    test('adjacent independent vowels disambiguated with _', () {
      expect(transliterate('अइ', from: Script.devanagari, to: Script.itrans), 'a_i');
    });

    test('consonant + halant + h gets _ separator', () {
      // Preserves the distinction between क्ह (k-halant-h) and ख (kh).
      expect(transliterate('क्ह', from: Script.devanagari, to: Script.itrans), 'k_ha');
    });
  });

  group('Tamil → ITRANS', () {
    test('bare consonant with implicit a', () {
      // Tamil க renders as "ka" with implicit vowel.
      expect(transliterate('க', from: Script.tamil, to: Script.itrans), 'ka');
    });

    test('sanskrit distinctions via superscripts', () {
      // க² = kh, க³ = g, க⁴ = gh
      expect(transliterate('க²', from: Script.tamil, to: Script.itrans), 'kha');
      expect(transliterate('க³', from: Script.tamil, to: Script.itrans), 'ga');
    });

    test('grantha letter for sh', () {
      expect(transliterate('ஶிவ', from: Script.tamil, to: Script.itrans), 'shiva');
    });

    test('Om character', () {
      expect(transliterate('ௐ', from: Script.tamil, to: Script.itrans), 'oM');
    });
  });

  group('Tamil → Kannada', () {
    test('sanskrit distinction preserved via superscript', () {
      // க³ங்க³ா → ಗಂಗಾ
      expect(transliterate('க³ங்க³ா', from: Script.tamil, to: Script.kannada), 'ಗಂಗಾ');
    });
  });

  group('Devanagari → RomanReadable', () {
    test('krishna', () {
      expect(
        transliterate('कृष्ण', from: Script.devanagari, to: Script.romanReadable),
        'krishna',
      );
    });

    test('ganga (nasal cluster collapses)', () {
      expect(
        transliterate('गङ्गा', from: Script.devanagari, to: Script.romanReadable),
        'ganga',
      );
    });

    test('pancha (palatal nasal cluster)', () {
      expect(
        transliterate('पञ्च', from: Script.devanagari, to: Script.romanReadable),
        'pancha',
      );
    });

    test('rama (word-final schwa drop is not applied; readable output keeps -a)', () {
      expect(
        transliterate('राम', from: Script.devanagari, to: Script.romanReadable),
        'rama',
      );
    });

    test('samskritam (anusvara before sibilant)', () {
      final String out = transliterate('संस्कृतम्',
          from: Script.devanagari, to: Script.romanReadable);
      // Aksharamukha emits a combining grapheme joiner (\u034F) after the
      // leftover anusvara m; strip it for the visible-string check.
      expect(out.replaceAll('\u034F', ''), 'samskritam');
    });

    test('shiva', () {
      expect(
        transliterate('शिव', from: Script.devanagari, to: Script.romanReadable),
        'shiva',
      );
    });

    test('Om', () {
      expect(
        transliterate('ॐ', from: Script.devanagari, to: Script.romanReadable),
        'Om',
      );
    });
  });

  group('preserved input', () {
    test('unknown characters (whitespace, punctuation) pass through', () {
      expect(transliterate('अ ब', from: Script.devanagari, to: Script.kannada), 'ಅ ಬ');
      expect(transliterate('अ, ब.', from: Script.devanagari, to: Script.itrans), 'a, ba.');
    });

    test('same-script is identity', () {
      const String s = 'राम';
      expect(transliterate(s, from: Script.devanagari, to: Script.devanagari), s);
    });
  });
}
