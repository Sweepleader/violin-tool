import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import '../../ffi/audio_bridge.dart';

class PitchResult {
  final String note;
  final double frequency;
  final double centsDeviation;
  final double confidence;

  const PitchResult({
    required this.note,
    required this.frequency,
    required this.centsDeviation,
    required this.confidence,
  });
}

class AudioEngine {
  final AudioBridge? _bridge;
  Isolate? _isolate;
  final _pitchController = StreamController<PitchResult>.broadcast();
  bool _initialized = false;

  AudioEngine() : _bridge = AudioBridge.instance;
  AudioEngine.test() : _bridge = null;

  Stream<PitchResult> get pitchStream => _pitchController.stream;
  bool get isInitialized => _bridge != null && _initialized;

  Future<void> initialize() async {
    if (_bridge == null) {
      _initialized = true;
      return;
    }
    final result = _bridge.init(44100, 256);
    if (result != 0) throw Exception('audio_init failed: $result');
    _initialized = true;
  }

  Future<void> start() async {
    if (!_initialized) await initialize();
    if (_bridge == null) return;
    final result = _bridge.start();
    if (result == -2) throw Exception('No microphone found');
    if (result == -3) throw Exception('Microphone started but capture failed. Check audio format support.');
    if (result != 0) throw Exception('audio_start failed: $result');

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_pollLoop, receivePort.sendPort);
    receivePort.listen((data) {
      if (data is _PitchData && data.confidence > 0.85) {
        _pitchController.add(_toPitchResult(data));
      }
    });
  }

  Future<void> stop() async {
    _isolate?.kill();
    _isolate = null;
    _bridge?.stop();
  }

  Future<void> dispose() async {
    await stop();
    _pitchController.close();
  }

  // Runs inside a Dart Isolate — polls C-side RingBuffer+YIN directly
  static void _pollLoop(SendPort sendPort) {
    final bridge = AudioBridge.instance;
    Timer.periodic(const Duration(milliseconds: 25), (_) {
      final result = bridge.pollPitch(44100);
      if (result.confidence > 0.0) {
        sendPort.send(_PitchData(result.frequency, result.confidence));
      }
    });
  }

  static PitchResult _toPitchResult(_PitchData data) {
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const a4 = 440.0;
    final semitones = 12 * log(data.frequency / a4) / log(2);
    final midiNote = 69 + semitones;
    final nearestNote = midiNote.round();
    final cents = (midiNote - nearestNote) * 100;
    final noteIndex = ((nearestNote % 12) + 12) % 12;
    final octave = (nearestNote ~/ 12) - 1;

    return PitchResult(
      note: '${noteNames[noteIndex]}$octave',
      frequency: data.frequency,
      centsDeviation: cents,
      confidence: data.confidence,
    );
  }
}

class _PitchData {
  final double frequency;
  final double confidence;
  _PitchData(this.frequency, this.confidence);
}
