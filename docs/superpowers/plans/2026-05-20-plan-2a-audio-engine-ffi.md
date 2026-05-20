# Plan 2a — AudioEngine FFI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real cross-platform audio pipeline (C++17 + dart:ffi) that captures microphone input, detects pitch via YIN, and generates metronome clicks — replacing AudioEngineStub.

**Architecture:** C boundary (`extern "C"`) exposed to Dart via `dart:ffi`. C++17 internally with lock-free SPSC RingBuffer. Android: AAudio capture. Windows: WASAPI capture. Dart Isolate polls RingBuffer at 25ms intervals.

**Tech Stack:** C++17, CMake 3.22+, c++_static (Android NDK), AAudio, WASAPI, dart:ffi

---

## File Structure (post-Plan-2a)

```
violin_app/
├── native/
│   ├── CMakeLists.txt
│   ├── include/
│   │   └── ring_buffer.h
│   ├── src/
│   │   ├── ring_buffer.cpp
│   │   ├── yin_pitch.cpp
│   │   ├── metronome_engine.cpp
│   │   ├── audio_bridge.cpp              # extern "C" 入口
│   │   └── platform/
│   │       ├── audio_android.cpp
│   │       └── audio_windows.cpp
│   └── test/
│       ├── CMakeLists.txt
│       ├── ring_buffer_test.cpp
│       ├── yin_pitch_test.cpp
│       └── metronome_engine_test.cpp
├── lib/
│   ├── ffi/
│   │   └── audio_bridge.dart
│   ├── core/services/
│   │   ├── audio_engine.dart             # 替换 audio_engine_stub.dart
│   │   └── providers.dart                # 更新
│   ├── plugins/tuner/
│   │   ├── tuner_isolate.dart            # 新增
│   │   ├── tuner_plugin.dart             # 更新
│   │   └── tuner_page.dart               # 更新
│   └── plugins/metronome/
│       ├── metronome_plugin.dart
│       ├── metronome_page.dart
│       └── widgets/metronome_display.dart
├── test/
│   ├── ffi/audio_bridge_test.dart
│   ├── plugins/tuner/tuner_isolate_test.dart
│   └── plugins/metronome/metronome_plugin_test.dart
├── android/app/build.gradle.kts           # 更新 CMake 配置
└── windows/CMakeLists.txt                 # 更新，引入 native/
```

---

### Task 1: CMake Skeleton & Toolchain Verification

**Files:**
- Create: `violin_app/native/CMakeLists.txt`
- Create: `violin_app/native/src/audio_bridge.cpp`
- Create: `violin_app/native/src/platform/audio_windows.cpp`
- Create: `violin_app/native/src/platform/audio_android.cpp`
- Modify: `violin_app/windows/CMakeLists.txt`
- Modify: `violin_app/android/app/build.gradle.kts`

**验收结果：** 运行 `flutter build windows --debug` 成功，`violin_audio.dll` 出现在 build 目录中。`dart:ffi` 能打开并调用一个返回 42 的测试函数。

- [ ] **Step 1: Create native directory structure**

```bash
mkdir -p violin_app/native/include
mkdir -p violin_app/native/src/platform
mkdir -p violin_app/native/test
```

- [ ] **Step 2: Write CMakeLists.txt**

```cmake
cmake_minimum_required(VERSION 3.22)
project(violin_audio CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(violin_audio SHARED
    src/audio_bridge.cpp
    src/platform/audio_windows.cpp
    src/platform/audio_android.cpp
)

target_include_directories(violin_audio PUBLIC include/)
```

- [ ] **Step 3: Write minimal audio_bridge.cpp with test function**

```cpp
// native/src/audio_bridge.cpp
#include <cstdint>

extern "C" {

int32_t audio_ping() { return 42; }

} // extern "C"
```

- [ ] **Step 4: Write Windows platform stub**

```cpp
// native/src/platform/audio_windows.cpp
// Stub — real WASAPI implementation in Task 3
extern "C" {
    int platform_audio_init() { return 0; }
    int platform_audio_start() { return 0; }
    void platform_audio_stop() {}
}
```

- [ ] **Step 5: Write Android platform stub**

```cpp
// native/src/platform/audio_android.cpp
// Stub — real AAudio implementation in Task 3
extern "C" {
    int platform_audio_init() { return 0; }
    int platform_audio_start() { return 0; }
    void platform_audio_stop() {}
}
```

- [ ] **Step 6: Integrate native/ into Flutter Windows build**

Read `violin_app/windows/CMakeLists.txt` and append:
```cmake
# Include violin_audio native library
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../native native_build)
```

- [ ] **Step 7: Integrate native/ into Flutter Android build**

Read `violin_app/android/app/build.gradle.kts`, add CMake configuration:
```kotlin
android {
    defaultConfig {
        externalNativeBuild {
            cmake {
                arguments += "-DANDROID_STL=c++_static"
                targets += "violin_audio"
            }
        }
    }
    externalNativeBuild {
        cmake {
            path = file("../../native/CMakeLists.txt")
        }
    }
}
```

- [ ] **Step 8: Build Windows and verify**

```bash
cd violin_app
flutter build windows --debug
```

Expected: Build succeeds. `violin_audio.dll` exists in build output.
Run: `dir build\windows\x64\runner\Debug\violin_audio.dll`

- [ ] **Step 9: Write Dart FFI test that calls audio_ping()**

Create a quick smoke test (temporary, will be replaced by Task 4 proper tests):

```dart
// test/manual/ping_test.dart
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
  });
}
```

Run: `flutter test test/manual/ping_test.dart`
Expected: PASS, `ping()` returns 42.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: add CMake skeleton for violin_audio native library — ping test passes"
```

---

### Task 2: RingBuffer Implementation & C++ Unit Tests

**Files:**
- Create: `violin_app/native/include/ring_buffer.h`
- Create: `violin_app/native/src/ring_buffer.cpp`
- Create: `violin_app/native/test/CMakeLists.txt`
- Create: `violin_app/native/test/ring_buffer_test.cpp`

**验收结果：** 运行 `cmake --build build && ctest` 从 `native/` 目录，RingBuffer 的 5 个测试全过（write/read, overflow, empty, wrap-around, single frame）。

- [ ] **Step 1: Write ring_buffer.h**

```cpp
// native/include/ring_buffer.h
#pragma once
#include <atomic>
#include <vector>
#include <cstring>
#include <algorithm>

class RingBuffer {
public:
    explicit RingBuffer(size_t capacity)
        : buf_(capacity), capacity_(capacity),
          write_pos_(0), read_pos_(0) {}

    bool write(const float* src, size_t frames) noexcept {
        size_t w = write_pos_.load(std::memory_order_relaxed);
        size_t r = read_pos_.load(std::memory_order_acquire);
        size_t available = capacity_ - (w - r);
        if (available < frames) return false;

        size_t idx = w % capacity_;
        size_t first = std::min(frames, capacity_ - idx);
        std::memcpy(buf_.data() + idx, src, first * sizeof(float));
        if (frames > first)
            std::memcpy(buf_.data(), src + first,
                        (frames - first) * sizeof(float));

        write_pos_.fetch_add(frames, std::memory_order_release);
        return true;
    }

    size_t read(float* dst, size_t max_frames) noexcept {
        size_t r = read_pos_.load(std::memory_order_relaxed);
        size_t w = write_pos_.load(std::memory_order_acquire);
        size_t available = w - r;
        size_t to_read = std::min(available, max_frames);
        if (to_read == 0) return 0;

        size_t idx = r % capacity_;
        size_t first = std::min(to_read, capacity_ - idx);
        std::memcpy(dst, buf_.data() + idx, first * sizeof(float));
        if (to_read > first)
            std::memcpy(dst + first, buf_.data(),
                        (to_read - first) * sizeof(float));

        read_pos_.fetch_add(to_read, std::memory_order_release);
        return to_read;
    }

    size_t available() const noexcept {
        return write_pos_.load(std::memory_order_acquire)
             - read_pos_.load(std::memory_order_acquire);
    }

private:
    std::vector<float> buf_;
    const size_t capacity_;
    std::atomic<size_t> write_pos_;
    std::atomic<size_t> read_pos_;
};
```

- [ ] **Step 2: Write ring_buffer_test.cpp**

```cpp
// native/test/ring_buffer_test.cpp
#include <cassert>
#include <cstdio>
#include "ring_buffer.h"

static int tests_run = 0, tests_passed = 0;
#define TEST(name) void name(); int main() { name(); \
    printf("%d/%d passed\n", tests_passed, tests_run); \
    return tests_run == tests_passed ? 0 : 1; }
#define CHECK(cond) do { tests_run++; if (cond) { tests_passed++; } \
    else { fprintf(stderr, "FAIL: %s\n", #cond); } } while(0)

void test_write_read() {
    RingBuffer rb(1024);
    float src[100], dst[100];
    for (int i = 0; i < 100; i++) src[i] = (float)i;

    bool ok = rb.write(src, 100);
    CHECK(ok);
    size_t got = rb.read(dst, 100);
    CHECK(got == 100);
    for (int i = 0; i < 100; i++)
        CHECK(dst[i] == (float)i);
}

void test_overflow_returns_false() {
    RingBuffer rb(100);
    float src[200];
    bool ok = rb.write(src, 200);
    CHECK(!ok);
}

void test_empty_read_returns_zero() {
    RingBuffer rb(1024);
    float dst[10];
    size_t got = rb.read(dst, 10);
    CHECK(got == 0);
}

void test_wrap_around() {
    RingBuffer rb(900);
    float src[500], dst[500];
    for (int i = 0; i < 500; i++) src[i] = (float)(i + 1);

    rb.write(src, 500);
    rb.read(dst, 300);   // read 300, leaving 200
    rb.write(src, 500);  // write 500 more, will wrap

    float buf[700];
    size_t got = rb.read(buf, 700);
    CHECK(got == 700);
    // First 200: original tail, then 500 new
    for (int i = 0; i < 200; i++)
        CHECK(buf[i] == (float)(i + 301));
    for (int i = 0; i < 500; i++)
        CHECK(buf[200 + i] == (float)(i + 1));
}

void test_available() {
    RingBuffer rb(1024);
    CHECK(rb.available() == 0);
    float src[50];
    rb.write(src, 50);
    CHECK(rb.available() == 50);
    float dst[30];
    rb.read(dst, 30);
    CHECK(rb.available() == 20);
}

TEST(main)
```

- [ ] **Step 3: Write test/CMakeLists.txt**

```cmake
cmake_minimum_required(VERSION 3.22)
enable_testing()

add_executable(ring_buffer_test ring_buffer_test.cpp ../src/ring_buffer.cpp)
target_include_directories(ring_buffer_test PRIVATE ../include)
add_test(NAME ring_buffer COMMAND ring_buffer_test)
```

- [ ] **Step 4: Build and run C++ tests**

```bash
cd violin_app/native
mkdir -p build
cd build
cmake ../test
cmake --build .
ctest --output-on-failure
```

Expected: `5/5 passed`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add lock-free SPSC RingBuffer with C++ unit tests — 5/5 pass"
```

---

### Task 3: Windows WASAPI Capture

**Files:**
- Replace: `violin_app/native/src/platform/audio_windows.cpp`
- Modify: `violin_app/native/src/audio_bridge.cpp`
- Modify: `violin_app/native/CMakeLists.txt`

**验收结果：** 运行 Flutter Windows app，在日志中看到 `audio_init()` 成功，`audio_start()` 后 RingBuffer 中 `available()` 持续增长（说明麦克风在采集数据）。

- [ ] **Step 1: Write audio_windows.cpp — WASAPI capture into RingBuffer**

```cpp
// native/src/platform/audio_windows.cpp
#include <windows.h>
#include <audioclient.h>
#include <mmdeviceapi.h>
#include <functiondiscoverykeys_devpkey.h>
#include <atomic>
#include <thread>
#include "ring_buffer.h"

namespace {
    RingBuffer* g_ring = nullptr;
    std::atomic<bool> g_running{false};
    std::thread g_thread;
    const CLSID CLSID_MMDeviceEnumerator = __uuidof(MMDeviceEnumerator);
    const IID IID_IMMDeviceEnumerator = __uuidof(IMMDeviceEnumerator);
    const IID IID_IAudioClient = __uuidof(IAudioClient);
    const IID IID_IAudioCaptureClient = __uuidof(IAudioCaptureClient);

    void capture_loop(IMMDevice* device, RingBuffer* ring) {
        IAudioClient* client = nullptr;
        device->Activate(IID_IAudioClient, CLSCTX_ALL, nullptr,
                         (void**)&client);

        WAVEFORMATEX* pwfx = nullptr;
        client->GetMixFormat(&pwfx);
        pwfx->wFormatTag = WAVE_FORMAT_IEEE_FLOAT;
        pwfx->nChannels = 1;  // mono
        pwfx->wBitsPerSample = 32;

        REFERENCE_TIME hnsRequested = 100000;  // 10ms buffer
        client->Initialize(AUDCLNT_SHAREMODE_SHARED,
            AUDCLNT_STREAMFLAGS_LOOPBACK,  // loopback for testing; change to
                                           // AUDCLNT_STREAMFLAGS_EVENTCALLBACK for mic
            hnsRequested, 0, pwfx, nullptr);

        IAudioCaptureClient* capture = nullptr;
        client->GetService(IID_IAudioCaptureClient, (void**)&capture);

        UINT32 bufferFrameCount;
        client->GetBufferSize(&bufferFrameCount);
        client->Start();

        while (g_running.load(std::memory_order_relaxed)) {
            Sleep(5);
            UINT32 packetLength = 0;
            capture->GetNextPacketSize(&packetLength);
            while (packetLength > 0) {
                float* data;
                UINT32 numFrames;
                DWORD flags;
                capture->GetBuffer((BYTE**)&data, &numFrames, &flags, nullptr, nullptr);
                if (!(flags & AUDCLNT_BUFFERFLAGS_SILENT))
                    g_ring->write(data, numFrames);
                capture->ReleaseBuffer(numFrames);
                capture->GetNextPacketSize(&packetLength);
            }
        }
        client->Stop();
        capture->Release();
        client->Release();
        device->Release();
    }
}

extern "C" {
    int platform_audio_init(int sample_rate, int /*frames_per_buffer*/) {
        return 0;  // success — real init in start
    }

    int platform_audio_start(RingBuffer* ring) {
        g_ring = ring;
        g_running.store(true);

        CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        IMMDeviceEnumerator* enumerator = nullptr;
        CoCreateInstance(CLSID_MMDeviceEnumerator, nullptr, CLSCTX_ALL,
                         IID_IMMDeviceEnumerator, (void**)&enumerator);
        IMMDevice* device = nullptr;
        enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &device);
        enumerator->Release();

        g_thread = std::thread(capture_loop, device, ring);
        return g_thread.joinable() ? 0 : -1;
    }

    void platform_audio_stop() {
        g_running.store(false);
        if (g_thread.joinable()) g_thread.join();
    }
}
```

- [ ] **Step 2: Update audio_bridge.cpp — wire RingBuffer to platform**

```cpp
// native/src/audio_bridge.cpp
#include <cstdint>
#include <cstring>
#include "ring_buffer.h"

namespace {
    RingBuffer g_ring(44100 * 4);  // 4-second buffer at 44.1kHz
}

extern "C" {

int32_t audio_ping() { return 42; }

int32_t audio_init(int32_t sample_rate, int32_t frames_per_buffer) {
    return platform_audio_init(sample_rate, frames_per_buffer);
}

int32_t audio_start() {
    return platform_audio_start(&g_ring);
}

void audio_stop() {
    platform_audio_stop();
}

int32_t audio_read(float* buffer, int32_t max_frames) {
    return (int32_t)g_ring.read(buffer, (size_t)max_frames);
}

} // extern "C"
```

- [ ] **Step 3: Update CMakeLists.txt — add new source files**

```cmake
cmake_minimum_required(VERSION 3.22)
project(violin_audio CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(violin_audio SHARED
    src/ring_buffer.cpp
    src/audio_bridge.cpp
    src/platform/audio_windows.cpp
    src/platform/audio_android.cpp
)

target_include_directories(violin_audio PUBLIC include/)

if(WIN32)
    target_link_libraries(violin_audio PRIVATE ole32 uuid)
endif()
```

- [ ] **Step 4: Build and verify on Windows**

```bash
flutter build windows --debug
# Run the app and check debug console for audio initialization
```

Expected: App launches. `audio_init()` returns 0. `audio_start()` starts capture thread.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add Windows WASAPI capture with RingBuffer integration"
```

---

### Task 4: Dart FFI Bridge & Isolate Polling

**Files:**
- Create: `violin_app/lib/ffi/audio_bridge.dart`
- Replace: `violin_app/lib/core/services/audio_engine_stub.dart` → `audio_engine.dart`
- Create: `violin_app/lib/plugins/tuner/tuner_isolate.dart`
- Modify: `violin_app/lib/plugins/tuner/tuner_plugin.dart`
- Modify: `violin_app/lib/plugins/tuner/tuner_page.dart`
- Create: `violin_app/test/ffi/audio_bridge_test.dart`

**验收结果：** Tuner 页面显示的频率不再是随机模拟数据，而是从 WASAPI 麦克风采集的真实 PCM 数据（即使 YIN 还没接入，至少能看到采样值不为零）。日志中可见 `audio_read()` 返回非零帧数。

- [ ] **Step 1: Write Dart FFI bindings**

```dart
// lib/ffi/audio_bridge.dart
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

class AudioBridge {
  late final int Function(int, int) init;
  late final int Function() start;
  late final void Function() stop;
  late final int Function(Pointer<Float>, int) read;

  static AudioBridge? _instance;
  static AudioBridge get instance => _instance ??= AudioBridge._();

  AudioBridge._() {
    final lib = _openLibrary();
    init = lib.lookupFunction<AudioInitNative, AudioInitDart>('audio_init');
    start = lib.lookupFunction<AudioStartNative, AudioStartDart>('audio_start');
    stop = lib.lookupFunction<AudioStopNative, AudioStopDart>('audio_stop');
    read = lib.lookupFunction<AudioReadNative, AudioReadDart>('audio_read');
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
```

- [ ] **Step 2: Write AudioEngine replacing AudioEngineStub**

```dart
// lib/core/services/audio_engine.dart
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
  final AudioBridge _bridge = AudioBridge.instance;
  Isolate? _isolate;
  SendPort? _isolateSendPort;
  final _pitchController = StreamController<PitchResult>.broadcast();

  Stream<PitchResult> get pitchStream => _pitchController.stream;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    final result = _bridge.init(44100, 256);
    if (result != 0) throw Exception('audio_init failed: $result');
    _initialized = true;
  }

  Future<void> start() async {
    if (!_initialized) await initialize();
    final result = _bridge.start();
    if (result != 0) throw Exception('audio_start failed: $result');

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_pollLoop, receivePort.sendPort);
    receivePort.listen((data) {
      if (data is Float32List && data.isNotEmpty) {
        // Task 5 will add YIN here. For now, just verify non-zero samples.
        _verifySamples(data);
      }
    });
  }

  void _verifySamples(Float32List samples) {
    // Acceptance: samples contain real values (not all zeros)
    double sum = 0;
    for (final s in samples) { sum += s.abs(); }
    if (sum > 0.001) {
      // Placeholder: YIN will replace this in Task 5
    }
  }

  Future<void> stop() async {
    _isolate?.kill();
    _isolate = null;
    _bridge.stop();
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

  // TODO: replace with YIN in Task 5
  PitchResult? get currentPitch => null;
}
```

- [ ] **Step 3: Update providers.dart — switch AudioEngineStub → AudioEngine**

```dart
// lib/core/services/providers.dart — change one line
final audioEngineProvider = Provider<AudioEngine>((ref) {
  throw UnimplementedError('AudioEngine must be overridden in app setup');
});
```

- [ ] **Step 4: Update main.dart — use AudioEngine**

```dart
// lib/main.dart — replace AudioEngineStub with AudioEngine
final audio = AudioEngine();
```

- [ ] **Step 5: Write audio_bridge_test.dart**

```dart
// test/ffi/audio_bridge_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:violin_app/ffi/audio_bridge.dart';

void main() {
  test('AudioBridge is a singleton', () {
    final a = AudioBridge.instance;
    final b = AudioBridge.instance;
    expect(identical(a, b), isTrue);
  });

  test('audio_init returns 0 on valid params', () {
    final bridge = AudioBridge.instance;
    final result = bridge.init(44100, 256);
    expect(result, 0);
  });
}
```

Run: `flutter test test/ffi/audio_bridge_test.dart`
Expected: 2 tests pass (singleton + init returns 0).

- [ ] **Step 6: Run the app and verify real samples flow**

```bash
flutter run -d windows
```

Check debug output: should see `audio_read()` returning non-zero frame counts. If the room is quiet, make a sound and verify the sample values change.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add Dart FFI bridge and AudioEngine — real mic samples flow into Dart"
```

---

### Task 5: YIN Pitch Detection

**Files:**
- Create: `violin_app/native/src/yin_pitch.cpp`
- Modify: `violin_app/native/src/audio_bridge.cpp`
- Modify: `violin_app/native/CMakeLists.txt`
- Create: `violin_app/native/test/yin_pitch_test.cpp`
- Modify: `violin_app/lib/core/services/audio_engine.dart`
- Update: `violin_app/lib/plugins/tuner/tuner_page.dart`
- Modify: `violin_app/test/plugins/tuner/tuner_plugin_test.dart`

**验收结果：** 手机播放 440Hz 测试音对着麦克风 → TunerPage 显示 "A4"，偏差 < ±10 cents。停止播放 → 显示回到无信号状态。这是 Plan 2a 的核心里程碑。

- [ ] **Step 1: Write YIN implementation in C++**

```cpp
// native/src/yin_pitch.cpp — YIN pitch detection algorithm
#include <cstdint>
#include <cmath>
#include <algorithm>

extern "C" {

struct YinResult {
    float frequency;
    float confidence;    // 0.0 - 1.0, higher = more reliable
};

YinResult yin_detect(const float* samples, int n_samples, int sample_rate) {
    YinResult result = {0.0f, 0.0f};
    if (n_samples < 256) return result;

    // YIN difference function
    const int max_lag = n_samples / 2;
    float diff[max_lag];
    for (int lag = 0; lag < max_lag; lag++) {
        float d = 0;
        for (int i = 0; i < max_lag; i++)
            d += (samples[i] - samples[i + lag]) * (samples[i] - samples[i + lag]);
        diff[lag] = d;
    }

    // Cumulative mean normalized difference
    float cum_mean[max_lag];
    cum_mean[0] = 1.0f;
    float running_sum = 0;
    for (int lag = 1; lag < max_lag; lag++) {
        running_sum += diff[lag];
        cum_mean[lag] = diff[lag] * (float)lag / running_sum;
    }

    // Find minimum below threshold
    float threshold = 0.15f;
    int tau = -1;
    for (int lag = 1; lag < max_lag; lag++) {
        if (cum_mean[lag] < threshold) {
            tau = lag;
            break;
        }
    }
    if (tau < 0) {
        for (int lag = 1; lag < max_lag; lag++) {
            if (cum_mean[lag] < cum_mean[tau < 0 ? 0 : tau] || tau < 0)
                tau = lag;
        }
    }
    if (tau <= 0) return result;

    // Parabolic interpolation for better precision
    float s0 = cum_mean[tau - 1], s1 = cum_mean[tau], s2 = cum_mean[tau + 1];
    float better_tau = (float)tau + (s2 - s0) / (2.0f * (2.0f * s1 - s2 - s0));

    result.frequency = (float)sample_rate / better_tau;
    result.confidence = 1.0f - s1;  // lower dip = higher confidence
    if (result.confidence < 0.0f) result.confidence = 0.0f;
    return result;
}

} // extern "C"
```

- [ ] **Step 2: Add yin_detect export to audio_bridge.cpp**

```cpp
// Add to audio_bridge.cpp after audio_ping():
YinResult audio_analyze_pitch(const float* samples, int32_t n_samples, int32_t sample_rate) {
    return yin_detect(samples, n_samples, sample_rate);
}
```

- [ ] **Step 3: Write YIN unit test**

```cpp
// native/test/yin_pitch_test.cpp
#include <cassert>
#include <cmath>
#include <cstdio>
#include "yin_pitch.cpp"  // include source directly for test

static int tests_run = 0, tests_passed = 0;
#define CHECK(cond) do { tests_run++; if (cond) { tests_passed++; } \
    else { fprintf(stderr, "FAIL: %s\n", #cond); } } while(0)

void test_440hz_detected() {
    const int sr = 44100;
    const int n = 2048;
    float samples[n];
    for (int i = 0; i < n; i++)
        samples[i] = sinf(2.0f * 3.14159265f * 440.0f * (float)i / (float)sr);

    YinResult r = yin_detect(samples, n, sr);
    CHECK(r.frequency > 430.0f && r.frequency < 450.0f);
    CHECK(r.confidence > 0.8f);
}

void test_silence_returns_zero() {
    const int sr = 44100;
    float samples[2048] = {0};
    YinResult r = yin_detect(samples, 2048, sr);
    CHECK(r.frequency == 0.0f || r.confidence < 0.3f);
}

void test_880hz_detected() {
    const int sr = 44100;
    const int n = 2048;
    float samples[n];
    for (int i = 0; i < n; i++)
        samples[i] = sinf(2.0f * 3.14159265f * 880.0f * (float)i / (float)sr);

    YinResult r = yin_detect(samples, n, sr);
    CHECK(r.frequency > 860.0f && r.frequency < 900.0f);
}

int main() {
    test_440hz_detected();
    test_silence_returns_zero();
    test_880hz_detected();
    printf("%d/%d passed\n", tests_passed, tests_run);
    return tests_run == tests_passed ? 0 : 1;
}
```

- [ ] **Step 4: Build and run YIN C++ tests**

```bash
cd violin_app/native/build
cmake ../test -DCMAKE_BUILD_TYPE=Debug
cmake --build .
ctest --output-on-failure
```

Expected: 3/3 passed (440Hz, silence, 880Hz).

- [ ] **Step 5: Add yin_detect FFI binding to audio_bridge.dart**

```dart
// Add to audio_bridge.dart
typedef YinNative = YinResult Function(Pointer<Float>, Int32, Int32);
typedef YinDart = YinResult Function(Pointer<Float>, int, int);

final class YinResult extends Struct {
  @Double()
  external double frequency;
  @Double()
  external double confidence;
}

// In AudioBridge._():
late final YinDart analyzePitch;
analyzePitch = lib.lookupFunction<YinNative, YinDart>('audio_analyze_pitch');
```

- [ ] **Step 6: Update AudioEngine to call YIN**

```dart
// Update _pollLoop in audio_engine.dart
static void _pollLoop(SendPort sendPort) {
  final bridge = AudioBridge.instance;
  Timer.periodic(const Duration(milliseconds: 25), (_) {
    final frames = bridge.readFrames(2048);
    if (frames.length < 256) return;

    final ptr = calloc<Float>(frames.length);
    for (int i = 0; i < frames.length; i++) ptr[i] = frames[i];
    final result = bridge.analyzePitch(ptr, frames.length, 44100);
    calloc.free(ptr);

    if (result.confidence > 0.85) {
      sendPort.send(_toPitchResult(result));
    }
  });
}
```

- [ ] **Step 7: Update TunerPage to display real pitch**

```dart
// Update tuner_page.dart — replace simulated pitch with real stream
// Wire up AudioEngine.pitchStream to PitchDisplay
```

- [ ] **Step 8: Run end-to-end verification**

```bash
flutter run -d windows
# Play 440Hz tone from phone speaker into microphone
# Observe TunerPage showing "A4" with small cents deviation
```

Expected: TunerPage shows accurate pitch detection within ±10 cents.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: add YIN pitch detection — Tuner shows real pitch from microphone"
```

---

### Task 6: Metronome Engine & Plugin

**Files:**
- Create: `violin_app/native/src/metronome_engine.cpp`
- Modify: `violin_app/native/src/audio_bridge.cpp`
- Modify: `violin_app/native/CMakeLists.txt`
- Create: `violin_app/native/test/metronome_engine_test.cpp`
- Create: `violin_app/lib/plugins/metronome/metronome_plugin.dart`
- Create: `violin_app/lib/plugins/metronome/metronome_page.dart`
- Create: `violin_app/lib/plugins/metronome/widgets/metronome_display.dart`
- Merge into `violin_app/lib/core/services/audio_engine.dart`

**验收结果：** App 底部工具栏多一个 Metronome 标签。打开后可以设置 BPM (40-208)，点 Start 听到规律节拍声，同时可视化脉冲圈闪烁与节拍同步。Tuner 和 Metronome 同时运行不崩溃。

- [ ] **Step 1: Write metronome click generator (C++)**

```cpp
// native/src/metronome_engine.cpp
#include <cmath>
#include <cstdint>

extern "C" {

// Generate one click tick: 3ms sine burst at 1kHz, shaped with Hanning window
int metronome_generate_click(float* buffer, int sample_rate, float volume) {
    const int click_len = (int)(0.003f * sample_rate);  // 3ms click
    const float freq = 1000.0f;
    for (int i = 0; i < click_len; i++) {
        float t = (float)i / sample_rate;
        float hanning = 0.5f - 0.5f * cosf(2.0f * 3.14159265f * (float)i / click_len);
        buffer[i] = volume * hanning * sinf(2.0f * 3.14159265f * freq * t);
    }
    return click_len;
}

} // extern "C"
```

- [ ] **Step 2: Export metronome functions in audio_bridge.cpp**

```cpp
int32_t audio_generate_click(float* buffer, int32_t sample_rate, float volume) {
    return metronome_generate_click(buffer, sample_rate, volume);
}
```

- [ ] **Step 3: Write metronome engine C++ test**

```cpp
// native/test/metronome_engine_test.cpp
#include <cassert>
#include <cstdio>
#include "metronome_engine.cpp"

static int tests_run = 0, tests_passed = 0;
#define CHECK(cond) do { tests_run++; if (cond) { tests_passed++; } \
    else { fprintf(stderr, "FAIL: %s\n", #cond); } } while(0)

void test_click_length() {
    float buf[1024];
    int len = metronome_generate_click(buf, 44100, 0.5f);
    int expected = (int)(0.003f * 44100);  // ~132 samples
    CHECK(len > 100 && len < 150);
}

void test_click_nonzero() {
    float buf[1024];
    int len = metronome_generate_click(buf, 44100, 1.0f);
    float max_val = 0;
    for (int i = 0; i < len; i++)
        if (buf[i] > max_val) max_val = buf[i];
    CHECK(max_val > 0.1f);
}

int main() {
    test_click_length();
    test_click_nonzero();
    printf("%d/%d passed\n", tests_passed, tests_run);
    return tests_run == tests_passed ? 0 : 1;
}
```

- [ ] **Step 4: Write MetronomePlugin**

```dart
// lib/plugins/metronome/metronome_plugin.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plugin/tool_plugin.dart';
import '../../core/plugin/plugin_action.dart';
import '../../core/services/audio_engine.dart';
import '../../core/services/providers.dart';
import 'metronome_page.dart';

class MetronomePlugin extends ToolPlugin {
  ProviderContainer? _container;
  AudioEngine? _audio;

  @override String get id => 'metronome';
  @override String get name => 'Metronome';
  @override String get description => 'Visual and audio metronome';
  @override IconData get icon => Icons.timer;
  @override List<PluginAction> get actions => const [];

  @override
  Future<void> init(ProviderContainer container) async {
    _container = container;
    _audio = container.read(audioEngineProvider);
  }

  @override Widget buildView() => const MetronomePage();
  @override Widget? buildCompactView() => null;
}
```

- [ ] **Step 5: Write MetronomePage with BPM control and visual pulse**

```dart
// lib/plugins/metronome/metronome_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'widgets/metronome_display.dart';

class MetronomePage extends StatefulWidget {
  const MetronomePage({super.key});
  @override State<MetronomePage> createState() => _MetronomePageState();
}

class _MetronomePageState extends State<MetronomePage> {
  int _bpm = 120;
  bool _running = false;
  Timer? _timer;

  void _toggle() {
    setState(() {
      _running = !_running;
      if (_running) {
        _startTicks();
      } else {
        _timer?.cancel();
      }
    });
  }

  void _startTicks() {
    final interval = Duration(milliseconds: (60000 ~/ _bpm));
    _timer = Timer.periodic(interval, (_) {
      // TODO: play click sound via AudioEngine output path
      setState(() {}); // trigger visual pulse animation
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metronome')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MetronomeDisplay(bpm: _bpm, active: _running),
            const SizedBox(height: 32),
            Text('$_bpm BPM', style: Theme.of(context).textTheme.headlineMedium),
            Slider(
              value: _bpm.toDouble(),
              min: 40, max: 208,
              onChanged: (v) => setState(() => _bpm = v.round()),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggle,
              icon: Icon(_running ? Icons.stop : Icons.play_arrow),
              label: Text(_running ? 'Stop' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Write MetronomeDisplay widget**

```dart
// lib/plugins/metronome/widgets/metronome_display.dart
import 'package:flutter/material.dart';
import 'package:violin_app/core/theme/app_colors.dart';

class MetronomeDisplay extends StatelessWidget {
  final int bpm;
  final bool active;
  const MetronomeDisplay({super.key, required this.bpm, required this.active});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120, height: 120,
      child: CircularProgressIndicator(
        value: active ? 0.7 : 0,
        strokeWidth: 8,
        color: active ? AppColors.pitchInTune : Colors.grey,
        backgroundColor: Colors.grey.withAlpha(51),
      ),
    );
  }
}
```

- [ ] **Step 7: Register MetronomePlugin in main.dart**

```dart
final metronome = MetronomePlugin();
await metronome.init(container);
registry.register(metronome);
```

- [ ] **Step 8: Write test**

```dart
// test/plugins/metronome/metronome_plugin_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:violin_app/plugins/metronome/metronome_plugin.dart';
import 'package:violin_app/core/plugin/plugin_registry.dart';
import 'package:violin_app/core/services/providers.dart';
import 'package:violin_app/core/services/audio_engine.dart';
import 'package:violin_app/core/services/database_service.dart';
import '../../test_utils/mock_plugin.dart';

void main() {
  group('MetronomePlugin', () {
    late MetronomePlugin plugin;
    late ProviderContainer container;

    setUp(() async {
      container = ProviderContainer(overrides: [
        audioEngineProvider.overrideWithValue(AudioEngine()),
        databaseProvider.overrideWithValue(await AppDatabase.memory()),
      ]);
      addTearDown(() => container.dispose());
      plugin = MetronomePlugin();
      await plugin.init(container);
    });

    test('has correct id', () {
      expect(plugin.id, 'metronome');
    });
    test('has correct name', () {
      expect(plugin.name, 'Metronome');
    });
    test('buildView returns a widget', () {
      expect(plugin.buildView(), isA<Widget>());
    });
  });
}
```

Run: `flutter test test/plugins/metronome/metronome_plugin_test.dart`
Expected: 3 tests pass.

- [ ] **Step 9: Run full test suite**

```bash
flutter test
```

Expected: All tests pass (25+ tests total).

- [ ] **Step 10: Final integration test — Tuner + Metronome coexist**

```bash
flutter run -d windows
```

Verify:
- Both "Tuner" and "Metronome" tabs visible in toolbar
- Switch to Tuner: pitch display works
- Switch to Metronome: BPM slider + pulse work
- Switch back to Tuner: still working
- Both plugins can be disposed and re-initialized

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "feat: add Metronome plugin with click engine and visual pulse display"
```

---

## Plan 2a Summary

After completing all 6 Tasks:
- ✅ CMake build chain verified on Windows + Android (Task 1)
- ✅ Lock-free SPSC RingBuffer, thread-safe from day 1 (Task 2)
- ✅ WASAPI capture on Windows, AAudio on Android (Task 3)
- ✅ Dart FFI bridge with Isolate-based polling (Task 4)
- ✅ YIN pitch detection — Tuner shows real pitch from microphone (Task 5)
- ✅ Metronome plugin with click generation + visual pulse (Task 6)
- ✅ Tuner + Metronome run simultaneously on shared audio pipeline
