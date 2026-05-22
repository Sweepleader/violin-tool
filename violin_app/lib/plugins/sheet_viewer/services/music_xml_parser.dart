import 'package:xml/xml.dart';

class ParsedNote {
  final String step;
  final int octave;
  final int measure;
  final int beat;
  final int duration;

  const ParsedNote({
    required this.step, required this.octave,
    required this.measure, required this.beat, required this.duration,
  });

  String get noteName => '$step$octave';
}

class MusicXmlParser {
  static List<ParsedNote> parse(String xmlString) {
    final doc = XmlDocument.parse(xmlString);
    final notes = <ParsedNote>[];
    int divisions = 4;
    int measureNum = 0;
    int beatPos = 0;

    for (final measure in doc.findAllElements('measure')) {
      measureNum++;
      // Get divisions if defined in this measure
      final attrs = measure.findAllElements('attributes');
      if (attrs.isNotEmpty) {
        final divs = attrs.first.findAllElements('divisions');
        if (divs.isNotEmpty) {
          divisions = int.tryParse(divs.first.innerText) ?? 4;
        }
      }
      for (final note in measure.findAllElements('note')) {
        if (note.findAllElements('rest').isNotEmpty) continue;
        final pitch = note.findAllElements('pitch');
        if (pitch.isEmpty) continue;
        final step = pitch.first.findAllElements('step').first.innerText;
        final octave = int.parse(pitch.first.findAllElements('octave').first.innerText);
        final dur = note.findAllElements('duration').first.innerText;
        final duration = int.tryParse(dur) ?? 1;

        notes.add(ParsedNote(
          step: step, octave: octave,
          measure: measureNum,
          beat: beatPos ~/ divisions + 1,
          duration: duration,
        ));
        beatPos += duration;
      }
    }
    return notes;
  }
}
