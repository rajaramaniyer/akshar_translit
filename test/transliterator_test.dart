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

    test('native numerals map to ASCII by default', () {
      expect(
        transliterate('०१२३४५६७८९',
            from: Script.devanagari, to: Script.telugu),
        '0123456789',
      );
    });

    test('useNativeNumerals: true preserves Telugu digits', () {
      const TransliterationOptions opts =
          TransliterationOptions(useNativeNumerals: true);
      expect(
        transliterate('०१२३४५६७८९',
            from: Script.devanagari, to: Script.telugu, options: opts),
        '\u0C66\u0C67\u0C68\u0C69\u0C6A\u0C6B\u0C6C\u0C6D\u0C6E\u0C6F',
      );
    });

    test('ASCII digits pass through unchanged', () {
      expect(
        transliterate('राम 15', from: Script.devanagari, to: Script.telugu),
        'రామ 15',
      );
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

  group('Devanagari → Tamil apostrophes', () {
    test('Sanskrit-marker apostrophes are stripped by default', () {
      // कृ would normally emit ருʼ; with the default option that ʼ is gone.
      final String out =
          transliterate('कृष्ण', from: Script.devanagari, to: Script.tamil);
      expect(out.contains('\u02BC'), isFalse);
      expect(out.contains('\u02EE'), isFalse);
    });

    test('tamilRemoveApostrophe: false keeps them for scholarly use', () {
      const TransliterationOptions opts =
          TransliterationOptions(tamilRemoveApostrophe: false);
      final String out = transliterate('कृष्ण',
          from: Script.devanagari, to: Script.tamil, options: opts);
      expect(out.contains('\u02BC'), isTrue);
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

  group('Devanagari → Tamil numerals', () {
    test('०१२३४५६७८९ becomes ASCII 0-9 by default', () {
      expect(
        transliterate('०१२३४५६७८९',
            from: Script.devanagari, to: Script.tamil),
        '0123456789',
      );
    });

    test('useNativeNumerals: true gives Tamil digits ௦-௯', () {
      const TransliterationOptions opts =
          TransliterationOptions(useNativeNumerals: true);
      expect(
        transliterate('०१२३४५६७८९',
            from: Script.devanagari,
            to: Script.tamil,
            options: opts),
        '\u0BE6\u0BE7\u0BE8\u0BE9\u0BEA\u0BEB\u0BEC\u0BED\u0BEE\u0BEF',
      );
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

    test('ZWSP word-break hint becomes real space', () {
      // Sanskrit compound with an invisible ZWSP between the two members.
      // In the Devanagari source it renders as zero width, so the compound
      // looks continuous. Every transliteration target promotes it to a
      // real space so a reader in any script gets the word seam.
      const String zwsp = '\u200B';
      expect(
        transliterate('राम${zwsp}सीता',
            from: Script.devanagari, to: Script.romanReadable),
        'rama sita',
      );
      expect(
        transliterate('राम${zwsp}सीता',
            from: Script.devanagari, to: Script.kannada),
        'ರಾಮ ಸೀತಾ',
      );
      expect(
        transliterate('राम${zwsp}सीता',
            from: Script.devanagari, to: Script.tamil),
        'ராம ஸீதா',
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

  group('Marathi / Hindi source', () {
    test('marathi → devanagari is byte-for-byte identity', () {
      const String s = 'नमस्कार, तुम्ही कसे आहात?';
      expect(transliterate(s, from: Script.marathi, to: Script.devanagari), s);
    });

    test('hindi → devanagari is byte-for-byte identity', () {
      const String s = 'नमस्ते, आप कैसे हैं?';
      expect(transliterate(s, from: Script.hindi, to: Script.devanagari), s);
    });

    test('marathi → tamil transliterates via Devanagari map', () {
      // Marathi content uses the same Devanagari codepoints, so the output
      // matches what Devanagari → Tamil would produce.
      final String viaMarathi =
          transliterate('राम', from: Script.marathi, to: Script.tamil);
      final String viaDev =
          transliterate('राम', from: Script.devanagari, to: Script.tamil);
      expect(viaMarathi, viaDev);
    });

    test('hindi → itrans transliterates via Devanagari map', () {
      final String viaHindi =
          transliterate('नमस्ते', from: Script.hindi, to: Script.itrans);
      final String viaDev =
          transliterate('नमस्ते', from: Script.devanagari, to: Script.itrans);
      expect(viaHindi, viaDev);
    });

    test('marathi source skips the compound splitter', () {
      // Even with splitCompounds=true, a Sanskrit-looking compound is
      // returned untouched when the source is declared as Marathi/Hindi.
      const String compound = 'रामकृष्ण';
      const TransliterationOptions opts =
          TransliterationOptions(splitCompounds: true);
      expect(
        transliterate(compound,
            from: Script.marathi, to: Script.marathi, options: opts),
        compound,
      );
      expect(
        transliterate(compound,
            from: Script.hindi, to: Script.hindi, options: opts),
        compound,
      );
    });
  });

  group('preservePeriod option', () {
    test('default: `.` in ITRANS becomes danda in Devanagari', () {
      // Baseline / current behaviour: ITRANS treats `.` as danda.
      final String out =
          transliterate('raam.', from: Script.itrans, to: Script.devanagari);
      expect(out.contains('\u0964'), isTrue); // U+0964 = ।
      expect(out.contains('.'), isFalse);
    });

    test('preservePeriod: `.` passes through unchanged', () {
      const TransliterationOptions opts =
          TransliterationOptions(preservePeriod: true);
      final String out = transliterate('raam.',
          from: Script.itrans, to: Script.devanagari, options: opts);
      expect(out.endsWith('.'), isTrue);
      expect(out.contains('\u0964'), isFalse);
    });

    test('preservePeriod: `..` also passes through', () {
      const TransliterationOptions opts =
          TransliterationOptions(preservePeriod: true);
      final String out = transliterate('raam..',
          from: Script.itrans, to: Script.devanagari, options: opts);
      expect(out.endsWith('..'), isTrue);
      expect(out.contains('\u0965'), isFalse); // U+0965 = ॥
    });

    test('preservePeriod does not affect Indic → Roman danda output', () {
      // Devanagari danda still renders as `.` in ITRANS output — the option
      // only skips signs whose *source* side is `.`, so the Dev-source
      // signs list (which uses `।`, not `.`) is unaffected.
      const TransliterationOptions opts =
          TransliterationOptions(preservePeriod: true);
      final String out = transliterate('राम।',
          from: Script.devanagari, to: Script.itrans, options: opts);
      expect(out.endsWith('.'), isTrue);
      expect(out.contains('\u0964'), isFalse);
    });
  });
}
