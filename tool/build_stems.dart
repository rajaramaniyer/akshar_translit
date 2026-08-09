// One-shot generator: reads csl-inflect's nominal-stem master file, extracts
// every compound-piece from column 3, converts SLP1 -> Devanagari, and writes
// lib/src/segmenter/data/stems_data.g.dart.
//
// Run from the akshar_translit package root:
//   dart run tool/build_stems.dart <path-to-lexnorm-all2.txt> [extras.txt]
//
// The optional second argument overrides the default supplementary
// word-list path (`tool/extra_stems.txt`). The default file is always
// consulted if it exists — one Devanagari stem per line, `#` starts a
// comment, blank lines ignored. Edit that file to teach the bundled
// splitter proper names, epic characters, and samasa compounds the
// csl-inflect lexicon doesn't cover; the next `build_stems` run bakes
// them in automatically.
//
// Source data is https://github.com/sanskrit-lexicon/csl-inflect (MIT). See
// ATTRIBUTION.md for the derived-data notice.

import 'dart:convert';
import 'dart:io';

/// Default supplementary word-list. Merged into every build when present.
const String _defaultExtrasPath = 'tool/extra_stems.txt';

// SLP1 letter -> Devanagari independent vowel.
const Map<String, String> _indep = <String, String>{
  'a': '\u0905', 'A': '\u0906', 'i': '\u0907', 'I': '\u0908',
  'u': '\u0909', 'U': '\u090A', 'f': '\u090B', 'F': '\u0960',
  'x': '\u090C', 'X': '\u0961', 'e': '\u090F', 'E': '\u0910',
  'o': '\u0913', 'O': '\u0914',
};

// SLP1 letter -> Devanagari vowel sign (matra); 'a' is empty (implicit).
const Map<String, String> _sign = <String, String>{
  'a': '', 'A': '\u093E', 'i': '\u093F', 'I': '\u0940',
  'u': '\u0941', 'U': '\u0942', 'f': '\u0943', 'F': '\u0944',
  'x': '\u0962', 'X': '\u0963', 'e': '\u0947', 'E': '\u0948',
  'o': '\u094B', 'O': '\u094C',
};

const Map<String, String> _cons = <String, String>{
  'k': '\u0915', 'K': '\u0916', 'g': '\u0917', 'G': '\u0918', 'N': '\u0919',
  'c': '\u091A', 'C': '\u091B', 'j': '\u091C', 'J': '\u091D', 'Y': '\u091E',
  'w': '\u091F', 'W': '\u0920', 'q': '\u0921', 'Q': '\u0922', 'R': '\u0923',
  't': '\u0924', 'T': '\u0925', 'd': '\u0926', 'D': '\u0927', 'n': '\u0928',
  'p': '\u092A', 'P': '\u092B', 'b': '\u092C', 'B': '\u092D', 'm': '\u092E',
  'y': '\u092F', 'r': '\u0930', 'l': '\u0932', 'v': '\u0935',
  'S': '\u0936', 'z': '\u0937', 's': '\u0938', 'h': '\u0939',
  'L': '\u0933',
};

const String _virama = '\u094D';
const String _anusvara = '\u0902';
const String _visarga = '\u0903';

/// Converts an SLP1 word to Devanagari. Returns null if any character can't
/// be mapped (so the caller can skip malformed rows).
String? slp1ToDevanagari(String slp) {
  final StringBuffer out = StringBuffer();
  bool lastWasCons = false;
  for (int i = 0; i < slp.length; i++) {
    final String c = slp[i];
    if (_cons.containsKey(c)) {
      out.write(_cons[c]);
      out.write(_virama);
      lastWasCons = true;
    } else if (_indep.containsKey(c)) {
      if (lastWasCons) {
        final String s = out.toString();
        out
          ..clear()
          ..write(s.substring(0, s.length - 1)) // drop virama
          ..write(_sign[c]);
      } else {
        out.write(_indep[c]);
      }
      lastWasCons = false;
    } else if (c == 'M') {
      out.write(_anusvara);
      lastWasCons = false;
    } else if (c == 'H') {
      out.write(_visarga);
      lastWasCons = false;
    } else {
      return null;
    }
  }
  return out.toString();
}

Future<void> main(List<String> argv) async {
  if (argv.isEmpty) {
    stderr.writeln(
        'usage: dart run tool/build_stems.dart <lexnorm-all2.txt> [extras.txt]');
    exit(2);
  }
  final File input = File(argv[0]);
  if (!await input.exists()) {
    stderr.writeln('not found: ${argv[0]}');
    exit(2);
  }
  // Default supplementary list — always merged when present so users can
  // grow the bundled dictionary by editing a single file. An explicit
  // second CLI arg overrides.
  final String extrasPath = argv.length > 1 ? argv[1] : _defaultExtrasPath;
  final File extrasFile = File(extrasPath);
  final bool extrasExplicit = argv.length > 1;
  final bool extrasUsed = await extrasFile.exists();
  if (extrasExplicit && !extrasUsed) {
    stderr.writeln('extras not found: $extrasPath');
    exit(2);
  }
  final File? extras = extrasUsed ? extrasFile : null;

  final Set<String> stems = <String>{};
  int rowsSeen = 0;
  int rowsUsed = 0;
  int piecesSkipped = 0;
  int piecesUnmappable = 0;

  await for (final String line in input
      .openRead()
      .transform(const SystemEncoding().decoder)
      .transform(const LineSplitter())) {
    final String t = line.trim();
    if (t.isEmpty || t.startsWith(';')) continue;
    rowsSeen++;
    final List<String> cols = line.split('\t');
    if (cols.length < 3) continue;
    final String decomp = cols[2].trim();
    if (decomp.isEmpty) continue;
    rowsUsed++;
    for (final String piece in decomp.split('-')) {
      if (piece.isEmpty) continue;
      // Require ≥ 3 SLP1 chars: filters 1-2 char prefixes (a-, ni-, su-)
      // that would over-split the DP output.
      if (piece.length < 3) {
        piecesSkipped++;
        continue;
      }
      // Anusvara/visarga can't be word-initial. Rows like `uBaya-Mkara`
      // are MW-annotation artefacts; skip so the segmenter never proposes
      // pieces starting with ं or ः.
      final String first = piece[0];
      if (first == 'M' || first == 'H') {
        piecesSkipped++;
        continue;
      }
      final String? deva = slp1ToDevanagari(piece);
      if (deva == null) {
        piecesUnmappable++;
        continue;
      }
      stems.add(deva);
    }
  }

  final int baseCount = stems.length;
  int extrasSeen = 0;
  int extrasAdded = 0;
  int extrasSkipped = 0;
  int extrasRejected = 0;
  if (extras != null) {
    await for (final String line in extras
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final int hashAt = line.indexOf('#');
      final String stripped = (hashAt >= 0 ? line.substring(0, hashAt) : line)
          .trim()
          // Strip joiners so hand-typed entries with ZWJ/ZWNJ still match.
          .replaceAll('\u200D', '')
          .replaceAll('\u200C', '');
      if (stripped.isEmpty) continue;
      extrasSeen++;
      if (!_isDevanagariWord(stripped)) {
        stderr.writeln('  reject (non-Devanagari): $stripped');
        extrasRejected++;
        continue;
      }
      if (stems.contains(stripped)) {
        extrasSkipped++;
        continue;
      }
      stems.add(stripped);
      extrasAdded++;
    }
  }

  final List<String> sorted = stems.toList()..sort();

  final Directory outDir =
      Directory('lib/src/segmenter/data');
  await outDir.create(recursive: true);
  final File outFile = File('${outDir.path}/stems_data.g.dart');

  final StringBuffer buf = StringBuffer()
    ..writeln('// GENERATED FILE. Do not edit.')
    ..writeln('// Source: csl-inflect (github.com/sanskrit-lexicon/csl-inflect), MIT.')
    ..writeln('// Regenerate with: dart run tool/build_stems.dart '
        '<path-to-lexnorm-all2.txt> [extras.txt]');
  if (extras != null) {
    buf.writeln('// Supplementary stems: ${extras.path} '
        '($extrasAdded new, $extrasSkipped dupes, $extrasRejected rejected)');
  }
  buf
    ..writeln()
    ..writeln('/// ${sorted.length} unique Devanagari stems, sorted.')
    ..writeln("const String kStemsPacked = '''");
  buf.writeAll(sorted, '\n');
  buf
    ..writeln("''';")
    ..writeln();

  await outFile.writeAsString(buf.toString());

  stdout
    ..writeln('rows seen:        $rowsSeen')
    ..writeln('rows used:        $rowsUsed')
    ..writeln('pieces skipped:   $piecesSkipped (< 3 SLP1 chars)')
    ..writeln('pieces unmapped:  $piecesUnmappable')
    ..writeln('base stems:       $baseCount');
  if (extras != null) {
    stdout
      ..writeln('extras seen:      $extrasSeen')
      ..writeln('extras added:     $extrasAdded')
      ..writeln('extras dupes:     $extrasSkipped')
      ..writeln('extras rejected:  $extrasRejected');
  }
  stdout
    ..writeln('unique stems:     ${sorted.length}')
    ..writeln('output:           ${outFile.path} '
        '(${await outFile.length()} bytes)');
}

/// Devanagari letters, matras, virama, anusvara, visarga, candrabindu,
/// nukta. Whitespace and punctuation are rejected — supplementary lines
/// are expected to hold a single stem, not phrases.
bool _isDevanagariWord(String s) {
  if (s.isEmpty) return false;
  for (int i = 0; i < s.length; i++) {
    final int c = s.codeUnitAt(i);
    if (c < 0x0900 || c > 0x097F) return false;
  }
  return true;
}
