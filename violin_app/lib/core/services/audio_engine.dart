import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
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

  /// Creates an AudioEngine connected to the real native library.
  AudioEngine() : _bridge = AudioBridge.instance;

  /// Creates an AudioEngine not connected to native code (for testing).
  AudioEngine.test() : _bridge = null;

  Stream<PitchResult> get pitchStream => _pitchController.stream;
  bool get isInitialized => _bridge != null && _initialized;

  Future<void> initialize() async {
    if (_bridge == null) {
      _initialized = true;
      return;
    }
    final result = _bridge!.init(44100, 256);
    if (result != 0) throw Exception('audio_init failed: $result');
    _initialized = true;
  }

  Future<void> start() async {
    if (!_initialized) await initialize();
    if (_bridge == null) return;
    final result = _bridge!.start();
    if (result != 0) throw Exception('audio_start failed: $result');

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_pollLoop, receivePort.sendPort);
    receivePort.listen((data) {
      if (data is Float32List && data.isNotEmpty) {
        // Task 5 will add YIN here
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

  static void _pollLoop(SendPort sendPort) {
    final bridge = AudioBridge.instance;
    Timer.periodic(const Duration(milliseconds: 25), (_) {
      final frames = bridge.readFrames(2048);
      if (frames.isNotEmpty) sendPort.send(frames);
    });
  }
}
