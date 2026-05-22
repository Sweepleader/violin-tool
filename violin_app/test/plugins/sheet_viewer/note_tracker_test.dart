import 'package:flutter_test/flutter_test.dart';
import 'package:violin_app/plugins/sheet_viewer/services/note_tracker.dart';
import 'package:violin_app/plugins/sheet_viewer/services/music_xml_parser.dart';

void main() {
  test('sliding window match finds correct note', () {
    final notes = [
      const ParsedNote(step: 'D', octave: 5, measure: 1, beat: 1, duration: 4),
      const ParsedNote(step: 'A', octave: 4, measure: 1, beat: 2, duration: 4),
      const ParsedNote(step: 'B', octave: 4, measure: 1, beat: 3, duration: 4),
      const ParsedNote(step: 'G', octave: 4, measure: 1, beat: 4, duration: 4),
    ];
    final tracker = NoteTracker(notes, startIndex: 0);

    var result = tracker.match('D', 5);
    expect(result, isNotNull);
    expect(result!.matchedIndex, 0);

    result = tracker.match('B', 4);
    expect(result, isNotNull);
    expect(result!.matchedIndex, 2);
  });

  test('returns null when no match in window', () {
    final notes = [
      const ParsedNote(step: 'D', octave: 5, measure: 1, beat: 1, duration: 4),
    ];
    final tracker = NoteTracker(notes, startIndex: 0);
    expect(tracker.match('F', 7), isNull);
  });
}
