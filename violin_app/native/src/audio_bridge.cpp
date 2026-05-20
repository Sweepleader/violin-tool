#include <cstdint>
#include <cstring>
#include "ring_buffer.h"

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

// Forward declarations from platform/
extern "C" {
int platform_audio_init(int sample_rate, int frames_per_buffer);
int platform_audio_start(RingBuffer* ring);
void platform_audio_stop();
}

namespace {
    RingBuffer g_ring(44100 * 4);  // 4-second buffer at 44.1kHz mono float
}

extern "C" {

EXPORT int32_t audio_ping() { return 42; }

EXPORT int32_t audio_init(int32_t sample_rate, int32_t frames_per_buffer) {
    return platform_audio_init(sample_rate, frames_per_buffer);
}

EXPORT int32_t audio_start() {
    return platform_audio_start(&g_ring);
}

EXPORT void audio_stop() {
    platform_audio_stop();
}

EXPORT int32_t audio_read(float* buffer, int32_t max_frames) {
    return (int32_t)g_ring.read(buffer, (size_t)max_frames);
}

EXPORT int32_t audio_available() {
    return (int32_t)g_ring.available();
}

} // extern "C"
