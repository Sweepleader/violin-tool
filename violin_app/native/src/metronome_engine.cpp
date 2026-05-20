#include <cmath>
#include <cstdint>

extern "C" {

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
