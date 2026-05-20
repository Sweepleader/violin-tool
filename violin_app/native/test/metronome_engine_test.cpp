#include <cassert>
#include <cstdio>
#include <cmath>

extern "C" {
int metronome_generate_click(float* buffer, int sample_rate, float volume);
}

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
