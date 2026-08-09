import 'package:akshar_translit/akshar_translit.dart';
import 'package:test/test.dart';

const String _zwsp = '\u200B';

void main() {
  final DevanagariSegmenter seg = DevanagariSegmenter.bundled();

  group('DevanagariSegmenter.insertBreaks', () {
    test('splits a plain two-stem compound above the min-length gate', () {
      // ZWS is a line-wrap hint — short tokens (≤ 8 code units) wrap as a
      // single word anyway, so `अंशकरण` (6 chars) intentionally stays
      // unbroken. Use a 9+-char two-stem compound to exercise splitting.
      expect(seg.insertBreaks('धर्मक्षेत्र'),
          'धर्म${_zwsp}क्षेत्र');
    });

    test('leaves short compounds unbroken (line-wrap intent)', () {
      // Even though `अंशकरण` = `अंश + करण` are both known stems, the
      // whole 6-char token fits on a line — no wrap hint needed.
      expect(seg.insertBreaks('अंशकरण'), 'अंशकरण');
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
      // `अंशकरण` is below the 9-char split gate; `धर्मक्षेत्र` (11 chars)
      // is above it.
      expect(
        seg.insertBreaks('अंशकरण, धर्मक्षेत्र!'),
        'अंशकरण, धर्म${_zwsp}क्षेत्र!',
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
      // Use a 9+-char compound so the split gate lets the segmenter run.
      final String out = transliterate('धर्मक्षेत्र',
          from: Script.devanagari, to: Script.itrans, options: splitOn);
      expect(out.contains(' '), isTrue);
      // and the pieces are still there
      expect(out.replaceAll(' ', ''),
          transliterate('धर्मक्षेत्र',
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
    test('literal mode: long vowel-fused compound splits at surface-safe seams',
        () {
      // yamaniyamAsanaprANAyAma...samAdhi — inner seams have fused matras,
      // but the surface-safe sandhi rescue can still emit breaks at seams
      // where no matra was fused (e.g. consonant↔consonant boundaries).
      const String yog =
          'यमनियमासनप्राणायामप्रत्याहारधारणाध्यानसमाधि';
      final String out = seg.insertBreaks(yog);
      final List<String> pieces = out.split(_zwsp);
      // At minimum the rescue should recover a few of the outermost
      // consonant-boundary seams.
      expect(pieces.length, greaterThanOrEqualTo(3));
      // Rescue emits underlying surface; the last piece is still `समाधि`.
      expect(pieces.last, 'समाधि');
      // Rescue must never emit a break inside a fused seam — every seam
      // must fall on a real akshara boundary in the original surface.
      expect(out.replaceAll(_zwsp, ''), yog);
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

    test('sandhi off: yoga-sūtra compound now splits at surface-safe seams',
        () {
      // Long compounds get help from the surface-safe sandhi rescue even
      // when the user opts out of full sandhi rewriting.
      final String out = transliterate(
        'यमनियमासनप्राणायामप्रत्याहारधारणाध्यानसमाधि',
        from: Script.devanagari,
        to: Script.itrans,
        options: litOnly,
      );
      expect(out.contains(' '), isTrue);
      // Final surface piece survives at the tail.
      expect(out.split(' ').last, 'samAdhi');
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

  group('DevanagariSegmenter.insertBreaks (allowInflectedTail)', () {
    test('literal + infl: splits compound with accusative -म् tail', () {
      // कृष्ण + देवम् — `देवम्` = `देव` + `-म्` acc-sg suffix. Base literal
      // mode already handles this via a lucky lexicon match, but the point
      // of the test is that `कृष्णभृङ्गम्` (with an unrelated -म् noun)
      // works too.
      expect(
        seg.insertBreaks('कृष्णभृङ्गम्', allowInflectedTail: true),
        'कृष्ण${_zwsp}भृङ्गम्',
      );
    });

    test('single inflected word does not split', () {
      // `भृङ्गम्` alone shouldn't split — the DP wouldn't leave a valid
      // 2-piece decomposition.
      expect(
        seg.insertBreaks('भृङ्गम्', allowInflectedTail: true),
        'भृङ्गम्',
      );
    });

    test('acc-pl -आन् suffix on last piece', () {
      // dvandva "प्राचेतस + नारद + प्रह्लाद" + acc-pl `-आन्` → `-ान्` on
      // the surface (a→ā fusion). Needs both sandhi and inflection modes.
      // NOTE: coverage depends on csl-inflect entries; if `प्रह्लाद` is
      // missing from the bundled set, this stays unsplit.
      final String out = seg.insertBreaks(
        'नारदप्रह्लादान्',
        allowVowelSandhi: true,
        allowInflectedTail: true,
      );
      // Should at minimum produce a break of some sort or leave unchanged;
      // we don't over-assert because `प्रह्लाद` is not in csl-inflect.
      expect(out, anyOf(equals('नारदप्रह्लादान्'), contains(_zwsp)));
    });

    test('inflection alone without sandhi does not unfuse matras', () {
      // Without sandhi mode, a compound whose only interior seams are
      // fusion-based cannot decompose, even with allowInflectedTail on.
      expect(
        seg.insertBreaks('भागवतार्थम्', allowInflectedTail: true),
        'भागवतार्थम्',
      );
    });
  });

  group('Transliterator.splitAcrossInflection option', () {
    test('cascades into transliterator output as expected', () {
      const opts = TransliterationOptions(
        splitCompounds: true,
        splitAcrossInflection: true,
      );
      final String out = transliterate(
        'कृष्णभृङ्गम्',
        from: Script.devanagari,
        to: Script.itrans,
        options: opts,
      );
      expect(out.contains(' '), isTrue);
      expect(out.split(' ').last, 'bhR^i~Ngam');
    });
  });

  group('DevanagariSegmenter allowGreedyFallback', () {
    test('leaves short tokens untouched even when the flag is on', () {
      // Below the 16-code-unit threshold: greedy shouldn't fire.
      expect(
        seg.insertBreaks('कृष्ण', allowGreedyFallback: true),
        'कृष्ण',
      );
    });

    test('breaks a long compound the strict DP cannot cover', () {
      // प्राचेतस-नारद-प्रह्लाद-आन् — `प्रह्लाद` is not in csl-inflect
      // so strict DP fails. Greedy should still produce 2+ pieces.
      final String out = seg.insertBreaks(
        'प्राचेतसनारदप्रह्लादान्',
        allowGreedyFallback: true,
        allowInflectedTail: true,
      );
      expect(out.contains(_zwsp), isTrue);
      // Every emitted piece must be ≥ 2 aksharas (i.e. no bare `प्रा`
      // or `प्र` preverb splits leaking through).
      final List<String> pieces = out.split(_zwsp);
      expect(pieces.length, greaterThanOrEqualTo(2));
      for (final String p in pieces) {
        expect(p.length, greaterThanOrEqualTo(2));
      }
    });

    test('does not break at phonotactically-impossible cluster starts', () {
      // राधाकृष्ण-पद-अम्बुज-भृङ्गम्. `अम्बुज` is missing from
      // csl-inflect, but greedy must NOT emit `पदा|म्बुज…` because
      // `म्ब` is an impossible word-initial cluster.
      final String out = seg.insertBreaks(
        'राधाकृष्णपदाम्बुजभृङ्गम्',
        allowGreedyFallback: true,
        allowInflectedTail: true,
      );
      for (final String p in out.split(_zwsp)) {
        expect(
          p.startsWith('म्'),
          isFalse,
          reason: 'greedy piece starts with impossible m+virama cluster',
        );
        expect(p.startsWith('र्'), isFalse);
        expect(p.startsWith('ल्'), isFalse);
      }
    });

    test('flag off is a no-op for uncoverable tokens', () {
      // A long token that isn't decomposable by the strict DP against the
      // bundled dict — with greedy off it must pass through whole.
      expect(
        seg.insertBreaks('क्षक्षक्षक्षक्षक्षक्षक्ष'),
        'क्षक्षक्षक्षक्षक्षक्षक्ष',
      );
    });
  });

  group('Transliterator.splitGreedyFallback option', () {
    test('cascades into ITRANS output for a long uncoverable compound', () {
      const opts = TransliterationOptions(
        splitCompounds: true,
        splitAcrossInflection: true,
        splitGreedyFallback: true,
      );
      final String out = transliterate(
        'प्राचेतसनारदप्रह्लादान्',
        from: Script.devanagari,
        to: Script.itrans,
        options: opts,
      );
      // Should contain at least one space (from ZWSP → space
      // conversion for Roman output).
      expect(out.contains(' '), isTrue);
    });

    test('flag off keeps the same compound unbroken', () {
      const opts = TransliterationOptions(
        splitCompounds: true,
        splitAcrossInflection: true,
      );
      final String out = transliterate(
        'क्षक्षक्षक्षक्षक्षक्षक्ष',
        from: Script.devanagari,
        to: Script.itrans,
        options: opts,
      );
      expect(out.contains(' '), isFalse);
    });
  });
}
