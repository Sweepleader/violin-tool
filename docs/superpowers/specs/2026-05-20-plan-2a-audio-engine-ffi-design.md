# Plan 2a — AudioEngine FFI 设计文档

> 状态：设计确认，待写 plan

## 目标

替换 `AudioEngineStub`，建立真实的跨平台音频管线：麦克风采集 → 音频处理（音高检测/节拍器） → 输出。

## 技术选型

| 层面 | 选型 | 说明 |
|------|------|------|
| 语言 | C boundary (`extern "C"`) + C++17 内部 | FFI 只暴露 C ABI，内部用 C++17 特性 |
| Android STL | `c++_static` | 避免跨 .so 的 `libc++_shared.so` 符号冲突 |
| 线程模型 | RingBuffer + Dart Isolate 轮询 (25ms) | SPSC lock-free buffer，C 侧写、Dart 侧读 |
| Android 音频 | AAudio (API 27+) | 未来可加 Oboe，当前直调 AAudio |
| Windows 音频 | WASAPI | 通过 PortAudio 或直调 |
| 构建 | CMake 3.22+ | 单 CMakeLists.txt，Android/Windows 分支 |

## 架构

```
┌─────────────────────────────────────────────────────┐
│                  Dart Layer                          │
│                                                      │
│  ┌──────────┐   ┌──────────┐   ┌──────────────────┐ │
│  │ Tuner    │   │ Metronome│   │ PitchMonitor/Rec │ │
│  │ Isolate  │   │ Isolate  │   │ Isolate          │ │
│  │ 25ms poll│   │          │   │                  │ │
│  └────┬─────┘   └────┬─────┘   └────────┬─────────┘ │
│       │              │                  │            │
│  ┌────┴──────────────┴──────────────────┴──────────┐ │
│  │              AudioBridge (dart:ffi)              │ │
│  │  audio_read() / audio_analyze_pitch()            │ │
│  └──────────────────────┬────────────────────────────┘ │
├─────────────────────────┼──────────────────────────────┤
│                  Native Layer (C++17)                   │
│                                                         │
│  ┌──────────────────────┴──────────────────────────┐   │
│  │              audio_bridge.cpp                     │   │
│  │              extern "C" { ... }                   │   │
│  └──┬───────────────┬───────────────┬───────────────┘   │
│     │               │               │                    │
│  ┌──┴──┐      ┌─────┴─────┐   ┌────┴──────┐            │
│  │Ring │      │ YIN Pitch │   │ Metronome │            │
│  │Buf  │      │ Engine    │   │ Engine    │            │
│  └──┬──┘      └───────────┘   └───────────┘            │
│     │                                                   │
│  ┌──┴──────────────────────────────────┐               │
│  │        platform/                     │               │
│  │  audio_android.cpp → AAudio         │               │
│  │  audio_windows.cpp → WASAPI          │               │
│  └─────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────┘
```

## CMake 结构

```
native/
├── CMakeLists.txt
├── include/
│   └── ring_buffer.h
├── src/
│   ├── ring_buffer.cpp
│   ├── yin_pitch.cpp
│   ├── metronome_engine.cpp
│   ├── audio_bridge.cpp          # extern "C" 边界
│   └── platform/
│       ├── audio_android.cpp     # AAudio
│       └── audio_windows.cpp     # WASAPI
```

## RingBuffer 设计

- SPSC (单生产者单消费者) lock-free
- `std::atomic<size_t>` + `memory_order_acquire/release`
- 无符号回绕，写指针永远领先读指针
- `write()` 丢帧不阻塞（音频回调内不能等待）
- `read()` 返回实际读取帧数

## Dart FFI 接口

```dart
// audio_bridge.dart
int audio_read(Pointer<Float> buffer, int maxFrames);  // → Float32List
int audio_analyze_pitch(Pointer<Float> frames, int count) → PitchResult;
```

- Tuner Isolate 每 25ms 轮询 `audio_read()`
- 只推送 `confidence > 0.85` 的结果到 UI，减少抖动
- 所有 FFI 调用在 Isolate 内，不阻塞 UI 线程

## 执行顺序

1. CMake 骨架 — 编译空 .so/.dll，验证工具链
2. RingBuffer + 单元测试（纯 C++）
3. `audio_android.cpp` — AAudio 麦克风采集
4. Dart FFI bridge + Isolate 轮询 — 打通数据链路
5. YIN 算法接入 — 调音器真实化
6. 节拍器 click engine — 最后，复用平台封装

## 关键风险

| 风险 | 应对 |
|------|------|
| MSVC vs NDK-Clang 编译行为差异 | 只用 C++17 标准特性，避免编译器扩展 |
| AAudio 设备兼容性 (API 27+) | 降级路径：API < 27 回退到 OpenSL ES |
| Dart GC 暂停影响 Isolate | 轮询间隔 25ms > 典型 GC 暂停 (10-15ms) |
| Flutter 原生库集成 | 通过 `flutter/CMakeLists.txt` 添加子项目 |
