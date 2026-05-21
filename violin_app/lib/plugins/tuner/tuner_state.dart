import '../../core/services/audio_engine.dart';

enum TunerState { idle, detecting, locked, inTune }

class TunerStateMachine {
  TunerState _state = TunerState.idle;
  String? _currentNote;
  double _displayCents = 0;
  double _displayFrequency = 0;
  int _silenceFrames = 0;
  int _stableNoteFrames = 0;
  final List<double> _recentCents = [];

  TunerState get state => _state;
  String get noteDisplay => _currentNote ?? '--';
  double get displayCents => _displayCents;
  double get displayFrequency => _displayFrequency;
  double get displayConfidence =>
      _state == TunerState.idle
          ? 0.0
          : _state == TunerState.detecting
              ? 0.4
              : _state == TunerState.locked
                  ? 0.8
                  : 1.0;

  void feed(PitchResult pitch) {
    _recentCents.add(pitch.centsDeviation);
    if (_recentCents.length > 10) _recentCents.removeAt(0);

    if (pitch.confidence < 0.85) {
      _silenceFrames++;
    } else {
      _silenceFrames = 0;
    }

    final bool silent = _silenceFrames > 25; // idle after ~1s silence
    final bool inTuneRange =
        _recentCents.length >= 5 && _recentCents.every((c) => c.abs() < 2.0);

    switch (_state) {
      case TunerState.idle:
        if (pitch.confidence > 0.85) {
          _state = TunerState.detecting;
          _currentNote = pitch.note;
          _displayCents = pitch.centsDeviation;
          _displayFrequency = pitch.frequency;
          _stableNoteFrames = 1;
        }
        break;

      case TunerState.detecting:
        if (silent) {
          _state = TunerState.idle;
          _currentNote = null;
          _stableNoteFrames = 0;
          break;
        }
        if (pitch.note == _currentNote) {
          _stableNoteFrames++;
        } else {
          _currentNote = pitch.note;
          _stableNoteFrames = 1;
        }
        if (_stableNoteFrames >= 3) {
          _state = TunerState.locked;
        }
        _displayCents += (pitch.centsDeviation - _displayCents) * 0.3;
        _displayFrequency += (pitch.frequency - _displayFrequency) * 0.3;
        break;

      case TunerState.locked:
        if (silent) {
          _state = TunerState.idle;
          _stableNoteFrames = 0;
          break;
        }
        if (pitch.note != _currentNote) {
          _currentNote = pitch.note;
          _stableNoteFrames = 1;
          _state = TunerState.detecting;
          break;
        }
        if (inTuneRange) {
          _state = TunerState.inTune;
        }
        _displayCents += (pitch.centsDeviation - _displayCents) * 0.25;
        _displayFrequency += (pitch.frequency - _displayFrequency) * 0.25;
        break;

      case TunerState.inTune:
        if (silent) {
          _state = TunerState.idle;
          break;
        }
        if (pitch.note != _currentNote || !inTuneRange) {
          _state = TunerState.locked;
          _stableNoteFrames = 0;
          break;
        }
        _displayCents += (pitch.centsDeviation - _displayCents) * 0.15;
        _displayFrequency += (pitch.frequency - _displayFrequency) * 0.15;
        break;
    }
  }

  void reset() {
    _state = TunerState.idle;
    _currentNote = null;
    _displayCents = 0;
    _displayFrequency = 0;
    _silenceFrames = 0;
    _stableNoteFrames = 0;
    _recentCents.clear();
  }
}
