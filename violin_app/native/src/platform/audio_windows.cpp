#define NOMINMAX
#include <windows.h>
#include <audioclient.h>
#include <mmdeviceapi.h>
#include <functiondiscoverykeys_devpkey.h>
#include <atomic>
#include <thread>
#include "ring_buffer.h"

namespace {

RingBuffer* g_ring = nullptr;
std::atomic<bool> g_running{false};
std::atomic<bool> g_capture_alive{false};
std::thread g_thread;
int g_sample_rate = 44100;

void capture_loop(IMMDevice* device) {
    try {
        HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        bool comOwned = SUCCEEDED(hr) || hr == S_FALSE;
        if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) return;

        IAudioClient* client = nullptr;
        hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                              (void**)&client);
        if (FAILED(hr)) { if (comOwned) CoUninitialize(); return; }

        WAVEFORMATEX* pwfx = nullptr;
        client->GetMixFormat(&pwfx);
        // Do NOT modify format in shared mode — accept what the device gives
        int nChannels = pwfx->nChannels;
        bool isFloat = (pwfx->wFormatTag == WAVE_FORMAT_IEEE_FLOAT);
        if (pwfx->wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
            auto* ext = reinterpret_cast<WAVEFORMATEXTENSIBLE*>(pwfx);
            isFloat = (ext->SubFormat == KSDATAFORMAT_SUBTYPE_IEEE_FLOAT);
        }

        REFERENCE_TIME hnsRequested = 100000;
        hr = client->Initialize(AUDCLNT_SHAREMODE_SHARED,
            0, hnsRequested, 0, pwfx, nullptr);
        CoTaskMemFree(pwfx);
        if (FAILED(hr)) {
            client->Release(); device->Release();
            if (comOwned) CoUninitialize();
            return;
        }

        IAudioCaptureClient* capture = nullptr;
        client->GetService(__uuidof(IAudioCaptureClient), (void**)&capture);
        client->Start();
        g_capture_alive.store(true);

        while (g_running.load(std::memory_order_relaxed)) {
            Sleep(5);
            UINT32 pktLen = 0;
            capture->GetNextPacketSize(&pktLen);
            while (pktLen > 0) {
                BYTE* rawData; UINT32 nFrames; DWORD flags;
                capture->GetBuffer(&rawData, &nFrames, &flags, nullptr, nullptr);
                if (!(flags & AUDCLNT_BUFFERFLAGS_SILENT)) {
                    std::vector<float> mono(nFrames);
                    if (isFloat) {
                        auto* src = reinterpret_cast<float*>(rawData);
                        for (UINT32 i = 0; i < nFrames; ++i) {
                            float sum = 0;
                            for (int ch = 0; ch < nChannels; ++ch)
                                sum += src[i * nChannels + ch];
                            mono[i] = sum / nChannels;
                        }
                    } else {
                        // Int16 fallback
                        auto* src = reinterpret_cast<short*>(rawData);
                        for (UINT32 i = 0; i < nFrames; ++i) {
                            float sum = 0;
                            for (int ch = 0; ch < nChannels; ++ch)
                                sum += src[i * nChannels + ch] / 32768.0f;
                            mono[i] = sum / nChannels;
                        }
                    }
                    g_ring->write(mono.data(), nFrames);
                }
                capture->ReleaseBuffer(nFrames);
                capture->GetNextPacketSize(&pktLen);
            }
        }

        client->Stop();
        capture->Release(); client->Release(); device->Release();
        if (comOwned) CoUninitialize();
    } catch (...) {}
    g_capture_alive.store(false);
}

} // anonymous namespace

extern "C" {

int platform_audio_init(int sample_rate, int /*frames_per_buffer*/) {
    g_sample_rate = sample_rate;
    return 0;
}

int platform_audio_start(RingBuffer* ring) {
    if (!ring) return -1;
    g_ring = ring;
    g_running.store(true);

    // COM may already be initialized by Flutter or the capture thread
    HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE && hr != S_FALSE) return -1;

    IMMDeviceEnumerator* enumerator = nullptr;
    hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                          __uuidof(IMMDeviceEnumerator), (void**)&enumerator);
    if (FAILED(hr)) return -1;

    IMMDevice* device = nullptr;
    hr = enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &device);
    enumerator->Release();
    if (FAILED(hr)) return -2;  // -2 = no microphone found

    g_capture_alive.store(false);
    try {
        g_thread = std::thread(capture_loop, device);
    } catch (...) {
        g_running.store(false);
        return -1;
    }
    // Wait up to 500ms for capture to confirm alive
    for (int i = 0; i < 50; ++i) {
        Sleep(10);
        if (g_capture_alive.load()) return 0;
    }
    return -3;  // thread started but WASAPI init failed
}

void platform_audio_stop() {
    g_running.store(false);
    if (g_thread.joinable()) g_thread.join();
    g_ring = nullptr;
}

} // extern "C"
