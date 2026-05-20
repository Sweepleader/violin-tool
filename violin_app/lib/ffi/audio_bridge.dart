import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

typedef AudioInitNative = Int32 Function(Int32, Int32);
typedef AudioInitDart = int Function(int, int);
typedef AudioStartNative = Int32 Function();
typedef AudioStartDart = int Function();
typedef AudioStopNative = Void Function();
typedef AudioStopDart = void Function();
typedef AudioReadNative = Int32 Function(Pointer<Float>, Int32);
typedef AudioReadDart = int Function(Pointer<Float>, int);
typedef AudioAvailableNative = Int32 Function();
typedef AudioAvailableDart = int Function();
typedef PollPitchNative = YinResult Function(Int32);
typedef PollPitchDart = YinResult Function(int);

final class YinResult extends Struct {
  @Float()
  external double frequency;

  @Float()
  external double confidence;
}

class AudioBridge {
  late final int Function(int, int) init;
  late final int Function() start;
  late final void Function() stop;
  late final int Function(Pointer<Float>, int) read;
  late final int Function() available;
  late final YinResult Function(int) pollPitch;

  static AudioBridge? _instance;
  static AudioBridge get instance => _instance ??= AudioBridge._();

  AudioBridge._() {
    final lib = _openLibrary();
    init = lib.lookupFunction<AudioInitNative, AudioInitDart>('audio_init');
    start = lib.lookupFunction<AudioStartNative, AudioStartDart>('audio_start');
    stop = lib.lookupFunction<AudioStopNative, AudioStopDart>('audio_stop');
    read = lib.lookupFunction<AudioReadNative, AudioReadDart>('audio_read');
    available = lib
        .lookupFunction<AudioAvailableNative, AudioAvailableDart>(
            'audio_available');
    pollPitch = lib
        .lookupFunction<PollPitchNative, PollPitchDart>(
            'audio_poll_pitch');
  }

  static DynamicLibrary _openLibrary() {
    if (Platform.isWindows) {
      return DynamicLibrary.open('violin_audio.dll');
    }
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libviolin_audio.so');
    }
    throw UnsupportedError('Unsupported platform');
  }

  Float32List readFrames(int maxFrames) {
    final ptr = calloc<Float>(maxFrames);
    try {
      final count = read(ptr, maxFrames);
      if (count <= 0) return Float32List(0);
      return Float32List.fromList(ptr.asTypedList(count));
    } finally {
      calloc.free(ptr);
    }
  }
}
