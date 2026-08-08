import 'package:akshar_translit/akshar_translit.dart';
void main() {
  final seg = DevanagariSegmenter.bundled();
  for (final s in ['यमनियम','यमनियमासन','यमनियमासनप्राणायाम','यमनियमासनप्राणायामप्रत्याहार','यमनियमासनप्राणायामप्रत्याहारधारणा','यमनियमासनप्राणायामप्रत्याहारधारणाध्यान','यमनियमासनप्राणायामप्रत्याहारधारणाध्यानसमाधि']) {
    final out = seg.insertBreaks(s);
    print('${s.length.toString().padLeft(3)} : $s -> ${out == s ? "(unchanged)" : out}');
  }
}
