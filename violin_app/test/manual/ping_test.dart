import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

typedef PingNative = Int32 Function();
typedef PingDart = int Function();

void main() {
  test('audio_ping returns 42', () {
    final libPath = Platform.isWindows
        ? 'build/windows/x64/runner/Debug/violin_audio.dll'
        : 'libviolin_audio.so';
    final dylib = DynamicLibrary.open(libPath);
    final ping = dylib.lookupFunction<PingNative, PingDart>('audio_ping');
    expect(ping(), 42);
    dylib.close(); // untested: might not be available in all SDK versions
  });
}
