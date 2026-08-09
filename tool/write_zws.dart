// Segment a Devanagari text file with the akshar_translit compound
// segmenter and write two sidecar files next to the source:
//
//   <name>.zws.txt        — real ZWSPs (U+200B) inserted at every
//                           discovered stem boundary. Visually
//                           identical to the original.
//   <name>.zws-pipe.txt   — same content but each ZWSP rendered as a
//                           literal `|` for easy eyeballing / diffing.
//
// Usage:
//   dart run tool/write_zws.dart <path-to-devanagari-text-file>

import "dart:io";
import "package:akshar_translit/akshar_translit.dart";

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln("usage: dart run tool/write_zws.dart <input.txt>");
    exit(64);
  }

  final File src = File(args.single);
  if (!src.existsSync()) {
    stderr.writeln("no such file: ${src.path}");
    exit(66);
  }

  final String original = src.readAsStringSync();

  const TransliterationOptions opts = TransliterationOptions(
    splitCompounds: true,
    splitAcrossVowelSandhi: false,
    splitAcrossInflection: true,
    splitGreedyFallback: true,
  );

  final String zwsOut = transliterate(
    original,
    from: Script.devanagari,
    to: Script.devanagari,
    options: opts,
  );

  final String base = _stripTxtSuffix(src.path);
  final String zwsPath = "$base.zws.txt";
  final String zwsPipePath = "$base.zws-pipe.txt";

  File(zwsPath).writeAsStringSync(zwsOut);
  File(zwsPipePath).writeAsStringSync(zwsOut.replaceAll("\u200B", "|"));

  final int zws = "\u200B".allMatches(zwsOut).length;
  print("Wrote $zwsPath");
  print("Wrote $zwsPipePath");
  print("ZWSPs inserted: $zws");
  print("Original chars: ${original.length}");
  print("Output chars:   ${zwsOut.length}");
}

String _stripTxtSuffix(String path) {
  const String ext = ".txt";
  if (path.toLowerCase().endsWith(ext)) {
    return path.substring(0, path.length - ext.length);
  }
  return path;
}
