#define NOMINMAX
#define INITGUID
#include <windows.h>
#include <audioclient.h>
#include <mmdeviceapi.h>
#include <ksmedia.h>
#include <functiondiscoverykeys_devpkey.h>
#include <atomic>
#include <thread>
#include <vector>
#include <algorithm>
#include "ring_buffer.h"

namespace {

RingBuffer* g_ring = nullptr;
std::atomic<bool> g_running{false};
std::atomic<bool> g_capture_ok{false};
std::thread g_thread;
int g_sample_rate = 44100;

struct CaptureFormat {
    int channels = 2;
    bool is_float = false;
    bool is_int16 = false;
    bool is_int32 = false;
};

CaptureFormat parse_format(const WAVEFORMATEX* wfx) {
    CaptureFormat fmt;
    fmt.channels = wfx->nChannels;
    if (wfx->wFormatTag == WAVE_FORMAT_IEEE_FLOAT) {
        fmt.is_float = true;
    } else if (wfx->wFormatTag == WAVE_FORMAT_PCM) {
        if (wfx->wBitsPerSample == 16) fmt.is_int16 = true;
        if (wfx->wBitsPerSample == 32) fmt.is_int32 = true;
    } else if (wfx->wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
        const auto* ext = reinterpret_cast<const WAVEFORMATEXTENSIBLE*>(wfx);
        if (ext->SubFormat == KSDATAFORMAT_SUBTYPE_IEEE_FLOAT) {
            fmt.is_float = true;
        } else if (ext->SubFormat == KSDATAFORMAT_SUBTYPE_PCM) {
            if (wfx->wBitsPerSample == 16) fmt.is_int16 = true;
            if (wfx->wBitsPerSample == 32) fmt.is_int32 = true;
        }
    }
    return fmt;
}

inline float frame_to_mono(const BYTE* src, int ch, int total_channels,
                            const CaptureFormat& fmt) {
    if (fmt.is_float)
        return reinterpret_cast<const float*>(src)[ch];
    if (fmt.is_int16)
        return reinterpret_cast<const int16_t*>(src)[ch] / 32768.0f;
    if (fmt.is_int32)
        return reinterpret_cast<const int32_t*>(src)[ch] / 2147483648.0f;
    return 0.f;
}

void capture_loop(IMMDevice* device) {
    try {
        HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        const bool com_owned = (SUCCEEDED(hr) || hr == S_FALSE);
        if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) { device->Release(); return; }

        IAudioClient* client = nullptr;
        hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL,
                              nullptr, (void**)&client);
        device->Release();
        if (FAILED(hr)) { if (com_owned) CoUninitialize(); return; }

        WAVEFORMATEX* pwfx = nullptr;
        client->GetMixFormat(&pwfx);
        const CaptureFormat fmt = parse_format(pwfx);

        hr = client->Initialize(AUDCLNT_SHAREMODE_SHARED,
                                0, 200000, 0, pwfx, nullptr);
        CoTaskMemFree(pwfx);
        if (FAILED(hr)) {
            client->Release();
            if (com_owned) CoUninitialize();
            return;
        }

        IAudioCaptureClient* capture = nullptr;
        hr = client->GetService(__uuidof(IAudioCaptureClient), (void**)&capture);
        if (FAILED(hr)) {
            client->Release();
            if (com_owned) CoUninitialize();
            return;
        }

        hr = client->Start();
        if (FAILED(hr)) {
            capture->Release(); client->Release();
            if (com_owned) CoUninitialize();
            return;
        }

        g_capture_ok.store(true, std::memory_order_release);

        std::vector<float> mono_buf;
        mono_buf.reserve(4096);

        while (g_running.load(std::memory_order_relaxed)) {
            Sleep(5);
            UINT32 pkt = 0;
            capture->GetNextPacketSize(&pkt);
            while (pkt > 0) {
                BYTE* raw_data = nullptr;
                UINT32 n_frames = 0;
                DWORD flags = 0;
                hr = capture->GetBuffer(&raw_data, &n_frames, &flags,
                                        nullptr, nullptr);
                if (SUCCEEDED(hr)) {
                    if (!(flags & AUDCLNT_BUFFERFLAGS_SILENT) && n_frames > 0) {
                        mono_buf.resize(n_frames);
                        const int stride = fmt.channels;
                        if (fmt.channels == 1 && fmt.is_float) {
                            std::memcpy(mono_buf.data(), raw_data,
                                        n_frames * sizeof(float));
                        } else {
                            for (UINT32 i = 0; i < n_frames; ++i) {
                                float sum = 0.f;
                                for (int ch = 0; ch < stride; ++ch)
                                    sum += frame_to_mono(
                                        raw_data + i * stride * sizeof(float),
                                        ch, stride, fmt);
                                mono_buf[i] = sum / stride;
                            }
                        }
                        g_ring->write(mono_buf.data(), n_frames);
                    }
                    capture->ReleaseBuffer(n_frames);
                }
                capture->GetNextPacketSize(&pkt);
            }
        }

        client->Stop();
        capture->Release(); client->Release();
        if (com_owned) CoUninitialize();
    } catch (...) {}
}

} // anonymous namespace

extern "C" {

int platform_audio_init(int sample_rate, int /*frames_per_buffer*/) {
    g_sample_rate = sample_rate;
    return 0;
}

int platform_audio_start(RingBuffer* ring) {
    if (!ring) return -1;
    if (g_thread.joinable()) {
        g_running.store(false);
        g_thread.join();
    }
    g_ring = ring;
    g_capture_ok.store(false);
    g_running.store(true);

    HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE && hr != S_FALSE) return -1;

    IMMDeviceEnumerator* enumerator = nullptr;
    hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                          __uuidof(IMMDeviceEnumerator), (void**)&enumerator);
    if (FAILED(hr)) return -1;

    IMMDevice* device = nullptr;
    hr = enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &device);
    enumerator->Release();
    if (FAILED(hr)) return -2;

    try {
        g_thread = std::thread(capture_loop, device);
    } catch (...) {
        g_running.store(false);
        device->Release();
        return -1;
    }

    for (int i = 0; i < 150; ++i) {
        Sleep(10);
        if (g_capture_ok.load(std::memory_order_acquire)) return 0;
    }

    g_running.store(false);
    if (g_thread.joinable()) g_thread.join();
    g_ring = nullptr;
    return -3;
}

void platform_audio_stop() {
    g_running.store(false);
    if (g_thread.joinable()) g_thread.join();
    g_capture_ok.store(false);
    g_ring = nullptr;
}

// ── Output (render) path ───────────────────────────────────────────────────

RingBuffer* g_out_ring = nullptr;
std::atomic<bool> g_out_running{false};
std::thread g_out_thread;

void render_loop(IMMDevice* device) {
    try {
        HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) { device->Release(); return; }

        IAudioClient* client = nullptr;
        hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL,
                              nullptr, (void**)&client);
        device->Release();
        if (FAILED(hr)) return;

        WAVEFORMATEX* pwfx = nullptr;
        client->GetMixFormat(&pwfx);
        const int nChannels = pwfx->nChannels;
        const auto fmt = parse_format(pwfx);

        hr = client->Initialize(AUDCLNT_SHAREMODE_SHARED,
                                0, 200000, 0, pwfx, nullptr);
        CoTaskMemFree(pwfx);
        if (FAILED(hr)) { client->Release(); return; }

        UINT32 bufferFrames;
        client->GetBufferSize(&bufferFrames);

        IAudioRenderClient* render = nullptr;
        client->GetService(__uuidof(IAudioRenderClient), (void**)&render);
        client->Start();

        // Total samples = frames × channels
        std::vector<float> silence(bufferFrames * nChannels, 0.0f);
        std::vector<float> mono(bufferFrames, 0.0f);
        std::vector<float> mix(bufferFrames * nChannels, 0.0f);

        while (g_out_running.load(std::memory_order_relaxed)) {
            Sleep(5);
            size_t got = g_out_ring->read(mono.data(), bufferFrames);
            if (got == 0) {
                std::memcpy(mix.data(), silence.data(),
                            bufferFrames * nChannels * sizeof(float));
            } else {
                // Expand mono → interleaved multi-channel
                for (UINT32 i = 0; i < bufferFrames; ++i) {
                    float val = (i < got) ? mono[i] : 0.0f;
                    for (int ch = 0; ch < nChannels; ++ch)
                        mix[i * nChannels + ch] = val;
                }
            }

            BYTE* dst;
            hr = render->GetBuffer(bufferFrames, &dst);
            if (SUCCEEDED(hr)) {
                std::memcpy(dst, mix.data(),
                            bufferFrames * nChannels * sizeof(float));
                render->ReleaseBuffer(bufferFrames, 0);
            }
        }

        client->Stop();
        render->Release(); client->Release();
    } catch (...) {}
}

} // anonymous namespace

extern "C" {

int platform_output_init(int sample_rate) {
    g_sample_rate = sample_rate;
    return 0;
}

int platform_output_start(RingBuffer* ring) {
    if (!ring) return -1;
    g_out_ring = ring;
    g_out_running.store(true);

    HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE && hr != S_FALSE) return -1;

    IMMDeviceEnumerator* enu = nullptr;
    hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                          __uuidof(IMMDeviceEnumerator), (void**)&enu);
    if (FAILED(hr)) return -1;

    IMMDevice* device = nullptr;
    hr = enu->GetDefaultAudioEndpoint(eRender, eConsole, &device);
    enu->Release();
    if (FAILED(hr)) return -1;

    try {
        g_out_thread = std::thread(render_loop, device);
        return g_out_thread.joinable() ? 0 : -1;
    } catch (...) {
        device->Release();
        return -1;
    }
}

void platform_output_stop() {
    g_out_running.store(false);
    if (g_out_thread.joinable()) g_out_thread.join();
    g_out_ring = nullptr;
}

} // extern "C"
