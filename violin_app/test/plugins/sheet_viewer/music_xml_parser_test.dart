import 'package:flutter_test/flutter_test.dart';
import 'package:violin_app/plugins/sheet_viewer/services/music_xml_parser.dart';

void main() {
  test('parses twinkle twinkle MusicXML correctly', () {
    const xml = '''<?xml version="1.0"?>
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1">
      <measure number="1"><attributes><divisions>4</divisions><time><beats>4</beats></time><clef><sign>G</sign><line>2</line></clef></attributes>
        <note><pitch><step>D</step><octave>5</octave></pitch><duration>4</duration></note>
        <note><pitch><step>A</step><octave>4</octave></pitch><duration>4</duration></note>
      </measure>
    </part></score-partwise>''';

    final notes = MusicXmlParser.parse(xml);
    expect(notes.length, 2);
    expect(notes[0].step, 'D');
    expect(notes[0].octave, 5);
    expect(notes[0].measure, 1);
    expect(notes[1].step, 'A');
    expect(notes[1].octave, 4);
  });

  test('parses sharp notes correctly', () {
    const xml = '''<?xml version="1.0"?>
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1">
      <measure number="1"><attributes><divisions>4</divisions></attributes>
        <note><pitch><step>F</step><alter>1</alter><octave>5</octave></pitch><duration>4</duration></note>
      </measure>
    </part></score-partwise>''';

    final notes = MusicXmlParser.parse(xml);
    expect(notes.length, 1);
    expect(notes[0].step, 'F'); // F with alter=1 = F# (name stays F, pitch detection maps to F#)
    expect(notes[0].octave, 5);
  });

  test('skips rests', () {
    const xml = '''<?xml version="1.0"?>
    <score-partwise><part-list><score-part id="P1"/></part-list>
    <part id="P1">
      <measure number="1"><attributes><divisions>4</divisions></attributes>
        <note><rest/></note>
        <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
      </measure>
    </part></score-partwise>''';

    final notes = MusicXmlParser.parse(xml);
    expect(notes.length, 1);
    expect(notes[0].step, 'C');
  });
}
