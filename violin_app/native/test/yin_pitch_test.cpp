#include <cassert>
#include <cmath>
#include <cstdio>

extern "C" {
struct YinResult { float frequency; float confidence; };
YinResult yin_detect(const float* samples, int n_samples, int sample_rate);
}

static int tests_run = 0, tests_passed = 0;
#define CHECK(cond) do { tests_run++; if (cond) { tests_passed++; } \
    else { fprintf(stderr, "FAIL: %s\n", #cond); } } while(0)

void test_440hz_detected() {
    const int sr = 44100;
    const int n = 2048;
    float* samples = new float[n];
    for (int i = 0; i < n; i++)
        samples[i] = sinf(2.0f * 3.14159265f * 440.0f * (float)i / (float)sr);

    YinResult r = yin_detect(samples, n, sr);
    CHECK(r.frequency > 430.0f && r.frequency < 450.0f);
    CHECK(r.confidence > 0.8f);
    delete[] samples;
}

void test_silence_returns_low_confidence() {
    const int sr = 44100;
    float* samples = new float[2048];
    for (int i = 0; i < 2048; i++) samples[i] = 0.0f;

    YinResult r = yin_detect(samples, 2048, sr);
    CHECK(r.frequency == 0.0f || r.confidence < 0.3f);
    delete[] samples;
}

void test_880hz_detected() {
    const int sr = 44100;
    const int n = 2048;
    float* samples = new float[n];
    for (int i = 0; i < n; i++)
        samples[i] = sinf(2.0f * 3.14159265f * 880.0f * (float)i / (float)sr);

    YinResult r = yin_detect(samples, n, sr);
    CHECK(r.frequency > 860.0f && r.frequency < 900.0f);
    delete[] samples;
}

int main() {
    test_440hz_detected();
    test_silence_returns_low_confidence();
    test_880hz_detected();
    printf("%d/%d passed\n", tests_passed, tests_run);
    return tests_run == tests_passed ? 0 : 1;
}
