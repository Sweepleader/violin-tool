#include <cstdint>
#include <cmath>
#include <algorithm>

extern "C" {

struct YinResult {
    float frequency;
    float confidence;
};

struct StrobeResult {
    float phase;
    float confidence;
};

YinResult yin_detect(const float* samples, int n_samples, int sample_rate) {
    YinResult result = {0.0f, 0.0f};
    if (n_samples < 256) return result;

    const int max_lag = n_samples / 2;
    float* diff = new float[max_lag];

    // YIN difference function
    for (int lag = 0; lag < max_lag; lag++) {
        float d = 0;
        for (int i = 0; i < max_lag; i++)
            d += (samples[i] - samples[i + lag]) * (samples[i] - samples[i + lag]);
        diff[lag] = d;
    }

    // Cumulative mean normalized difference
    float* cum_mean = new float[max_lag];
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
        float best = 1.0f;
        for (int lag = 1; lag < max_lag; lag++) {
            if (cum_mean[lag] < best) { best = cum_mean[lag]; tau = lag; }
        }
    }
    if (tau <= 0 || tau >= max_lag - 1) {
        delete[] diff;
        delete[] cum_mean;
        return result;
    }

    // Parabolic interpolation
    float s0 = cum_mean[tau - 1], s1 = cum_mean[tau], s2 = cum_mean[tau + 1];
    float denom = 2.0f * (2.0f * s1 - s2 - s0);
    float better_tau = denom != 0.0f ? (float)tau + (s2 - s0) / denom : (float)tau;
    if (better_tau <= 0.0f || !std::isfinite(better_tau)) {
        delete[] diff;
        delete[] cum_mean;
        return result;
    }
    result.frequency = (float)sample_rate / better_tau;
    result.confidence = 1.0f - s1;
    if (result.confidence < 0.0f) result.confidence = 0.0f;

    delete[] diff;
    delete[] cum_mean;
    return result;
}

// Stroboscopic tuner: phase comparison at a reference frequency.
// Returns phase 0~1. Phase change rate = frequency error.
// Phase_stable = in tune; phase_increasing = sharp; phase_decreasing = flat.
StrobeResult strobe_detect(const float* samples, int n,
                            float ref_freq, int sample_rate) {
    StrobeResult r = {0.0f, 0.0f};
    if (n < 64 || ref_freq <= 0) return r;

    float I = 0, Q = 0;
    for (int i = 0; i < n; i++) {
        float t = (float)i / sample_rate;
        float angle = 2.0f * 3.14159265f * ref_freq * t;
        I += samples[i] * cosf(angle);
        Q += samples[i] * sinf(angle);
    }
    float phase = atan2f(Q, I) / (2.0f * 3.14159265f);
    if (phase < 0) phase += 1.0f;
    float magnitude = sqrtf(I * I + Q * Q) / (n / 2);
    r.phase = phase;
    r.confidence = magnitude;
    return r;
}

} // extern "C"
