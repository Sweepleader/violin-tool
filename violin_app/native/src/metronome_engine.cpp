#include <cmath>
#include <cstdint>
#include <cstdlib>

extern "C" {

// Generate a percussive sine click with exponential decay + noise layer.
// Returns number of samples written. Output is float (will be converted
// by the render loop if the device uses int16 format).
int metronome_generate_click(float* buffer, int sample_rate, float volume) {
    const float duration_ms = 30.f;
    const float freq_hz = 1000.f;
    int n = (int)(sample_rate * duration_ms / 1000.f);
    if (n > 2048) n = 2048;

    for (int i = 0; i < n; i++) {
        float t = (float)i / sample_rate;
        float env = expf(-t * 120.f); // exponential decay
        float osc = sinf(2.f * 3.14159f * freq_hz * t);
        // noise layer for wood-like timbre
        float noise = ((float)rand() / (float)RAND_MAX) * 2.f - 1.f;
        float sample = (0.7f * osc + 0.3f * noise) * env * volume;
        buffer[i] = sample;
    }
    return n;
}

} // extern "C"
