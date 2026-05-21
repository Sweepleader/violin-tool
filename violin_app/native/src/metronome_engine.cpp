#include <cmath>
#include <cstdint>

extern "C" {

int metronome_generate_click(float* buffer, int sample_rate, float volume) {
    const float duration = 0.020f; // 20ms
    const int click_len = (int)(duration * sample_rate);
    const float f1 = 2000.0f;      // start frequency
    const float f2 = 400.0f;       // end frequency (percussive sweep down)

    for (int i = 0; i < click_len; i++) {
        float t = (float)i / sample_rate;
        // Hanning envelope
        float env = 0.5f - 0.5f * cosf(2.0f * 3.14159265f * (float)i / click_len);
        // Linear freq sweep: f(t) = f1 + (f2-f1)*t/duration
        // Phase = 2π * ∫ f(τ)dτ = 2π * [f1*t + 0.5*(f2-f1)*t²/duration]
        float phase = 2.0f * 3.14159265f *
            (f1 * t + 0.5f * (f2 - f1) * t * t / duration);
        buffer[i] = volume * env * sinf(phase);
    }
    return click_len;
}

} // extern "C"
