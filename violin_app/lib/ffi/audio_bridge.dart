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
typedef StrobePollNative = StrobeResult Function(Float, Int32);
typedef StrobePollDart = StrobeResult Function(double, int);
typedef OutputStartNative = Int32 Function();
typedef OutputStartDart = int Function();
typedef OutputStopNative = Void Function();
typedef OutputStopDart = void Function();
typedef OutputWriteNative = Int32 Function(Pointer<Float>, Int32);
typedef OutputWriteDart = int Function(Pointer<Float>, int);
typedef PlayClickNative = Int32 Function(Int32, Float);
typedef PlayClickDart = int Function(int, double);
typedef OutputFrameNative = Int64 Function();
typedef OutputFrameDart = int Function();
typedef MetroStartNative = Void Function(Int32, Int32);
typedef MetroStartDart = void Function(int, int);
typedef MetroStopNative = Void Function();
typedef MetroStopDart = void Function();
typedef MetroBeatCountNative = Int32 Function();
typedef MetroBeatCountDart = int Function();

final class YinResult extends Struct {
  @Float()
  external double frequency;
  @Float()
  external double confidence;
}

final class StrobeResult extends Struct {
  @Float()
  external double phase;
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
  late final StrobeResult Function(double, int) strobePoll;
  late final int Function() outputStart;
  late final void Function() outputStop;
  late final int Function(Pointer<Float>, int) outputWrite;
  late final int Function(int, double) playClick;
  late final int Function() outputFrame;
  late final void Function(int, int) metroStart;
  late final void Function() metroStop;
  late final int Function() metroBeatCount;

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
    strobePoll = lib
        .lookupFunction<StrobePollNative, StrobePollDart>(
            'audio_strobe_poll');
    outputStart = lib
        .lookupFunction<OutputStartNative, OutputStartDart>(
            'audio_output_start');
    outputStop = lib
        .lookupFunction<OutputStopNative, OutputStopDart>(
            'audio_output_stop');
    outputWrite = lib
        .lookupFunction<OutputWriteNative, OutputWriteDart>(
            'audio_output_write');
    playClick = lib
        .lookupFunction<PlayClickNative, PlayClickDart>(
            'audio_play_click');
    outputFrame = lib
        .lookupFunction<OutputFrameNative, OutputFrameDart>(
            'audio_output_frame');
    metroStart = lib
        .lookupFunction<MetroStartNative, MetroStartDart>(
            'audio_metronome_start');
    metroStop = lib
        .lookupFunction<MetroStopNative, MetroStopDart>(
            'audio_metronome_stop');
    metroBeatCount = lib
        .lookupFunction<MetroBeatCountNative, MetroBeatCountDart>(
            'audio_metro_beat_count');
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
