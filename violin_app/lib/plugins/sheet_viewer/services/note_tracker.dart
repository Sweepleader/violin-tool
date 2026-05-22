import 'music_xml_parser.dart';

class NoteTracker {
  final List<ParsedNote> _notes;
  int _currentIndex;
  static const _windowSize = 3;

  NoteTracker(this._notes, {required int startIndex})
      : _currentIndex = startIndex;

  TrackResult? match(String step, int octave) {
    final start = (_currentIndex - _windowSize).clamp(0, _notes.length - 1);
    final end = (_currentIndex + _windowSize).clamp(0, _notes.length - 1);

    for (int i = start; i <= end; i++) {
      if (_notes[i].step == step && _notes[i].octave == octave) {
        _currentIndex = i;
        return TrackResult(i);
      }
    }
    return null;
  }

  int get currentIndex => _currentIndex;
  ParsedNote get currentNote => _notes[_currentIndex];
  int get noteCount => _notes.length;
}

class TrackResult {
  final int matchedIndex;
  TrackResult(this.matchedIndex);
}
