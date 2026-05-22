#include <cstdint>
#include <cstring>
#include "ring_buffer.h"

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

// Forward declarations from yin_pitch.cpp
extern "C" {
struct YinResult { float frequency; float confidence; };
struct StrobeResult { float phase; float confidence; };
YinResult yin_detect(const float* samples, int n_samples, int sample_rate);
StrobeResult strobe_detect(const float* samples, int n, float ref_freq, int sample_rate);
}

// Forward declarations from metronome_engine.cpp
extern "C" {
int metronome_generate_click(float* buffer, int sample_rate, float volume);
}

// Forward declarations from platform/
extern "C" {
int platform_audio_init(int sample_rate, int frames_per_buffer);
int platform_audio_start(RingBuffer* ring);
void platform_audio_stop();
int platform_output_start(RingBuffer* ring);
void platform_output_stop();
int64_t platform_output_frame();
void platform_metronome_start(int bpm, int sample_rate);
void platform_metronome_stop();
int32_t platform_metro_beat_count();
}

namespace {
    RingBuffer g_ring(44100 * 4);       // capture buffer
    RingBuffer g_out(44100 * 2);        // output buffer (2 seconds)
    // YIN smoothing state
    float g_freq_history[5] = {};
    int g_freq_idx = 0;
    float g_ema_freq = 0;
    float g_ema_conf = 0;
    bool g_smoothing_init = false;
}

static float median5(float a[5]) {
    float b[5];
    for (int i = 0; i < 5; i++) b[i] = a[i];
    for (int i = 0; i < 4; i++)
        for (int j = i + 1; j < 5; j++)
            if (b[i] > b[j]) { float t = b[i]; b[i] = b[j]; b[j] = t; }
    return b[2];
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

EXPORT YinResult audio_analyze_pitch(const float* samples,
                                      int32_t n_samples,
                                      int32_t sample_rate) {
    return yin_detect(samples, n_samples, sample_rate);
}

EXPORT YinResult audio_poll_pitch(int32_t sample_rate) {
    float buf[4096];
    size_t n = g_ring.read(buf, 4096);
    if (n < 256) {
        YinResult r = {0.0f, 0.0f};
        return r;
    }
    YinResult raw = yin_detect(buf, (int)n, sample_rate);
    if (raw.confidence < 0.85f) {
        return raw;
    }
    g_freq_history[g_freq_idx % 5] = raw.frequency;
    g_freq_idx++;
    float med_freq = median5(g_freq_history);

    const float alpha = 0.15f;
    if (!g_smoothing_init) {
        g_ema_freq = med_freq;
        g_ema_conf = raw.confidence;
        g_smoothing_init = true;
    } else {
        g_ema_freq = alpha * med_freq + (1.0f - alpha) * g_ema_freq;
        g_ema_conf = alpha * raw.confidence + (1.0f - alpha) * g_ema_conf;
    }
    YinResult out = {g_ema_freq, g_ema_conf};
    return out;
}

EXPORT int32_t audio_generate_click(float* buffer, int32_t sample_rate,
                                    float volume) {
    return metronome_generate_click(buffer, sample_rate, volume);
}

EXPORT StrobeResult audio_strobe_poll(float ref_freq, int32_t sample_rate) {
    float buf[4096];
    size_t n = g_ring.read(buf, 4096);
    if (n < 64) {
        StrobeResult r = {0.0f, 0.0f};
        return r;
    }
    return strobe_detect(buf, (int)n, ref_freq, sample_rate);
}

// ── Output path ────────────────────────────────────────────────

EXPORT int32_t audio_output_start() {
    return platform_output_start(&g_out);
}

EXPORT void audio_output_stop() {
    platform_output_stop();
}

// Write PCM frames into the output ring buffer (non-blocking)
EXPORT int32_t audio_output_write(const float* data, int32_t frames) {
    if (!data || frames <= 0) return 0;
    g_out.write(data, (size_t)frames);
    return frames;
}

// Generate a metronome click and write directly to output buffer
EXPORT int32_t audio_play_click(int32_t sample_rate, float volume) {
    float buf[1024];
    int len = metronome_generate_click(buf, sample_rate, volume);
    if (len > 0) g_out.write(buf, (size_t)len);
    return len;
}

EXPORT int64_t audio_output_frame() {
    return platform_output_frame();
}

EXPORT void audio_metronome_start(int32_t bpm, int32_t sample_rate) {
    platform_metronome_start(bpm, sample_rate);
}

EXPORT void audio_metronome_stop() {
    platform_metronome_stop();
}

EXPORT int32_t audio_metro_beat_count() {
    return platform_metro_beat_count();
}

} // extern "C"
