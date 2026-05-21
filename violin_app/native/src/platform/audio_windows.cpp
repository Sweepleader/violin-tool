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
std::thread g_thread;
int g_sample_rate = 44100;

void capture_loop(IMMDevice* device) {
    try {
        // COM must be initialized on THIS thread
        HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        bool comOwned = SUCCEEDED(hr);
        if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) return;

        IAudioClient* client = nullptr;
        hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                              (void**)&client);
        if (FAILED(hr)) {
            if (comOwned) CoUninitialize();
            return;
        }

        WAVEFORMATEX* pwfx = nullptr;
        client->GetMixFormat(&pwfx);
        pwfx->wFormatTag = WAVE_FORMAT_IEEE_FLOAT;
        pwfx->nChannels = 1;
        pwfx->wBitsPerSample = 32;
        pwfx->nBlockAlign = 4;
        pwfx->nAvgBytesPerSec = pwfx->nSamplesPerSec * 4;

        REFERENCE_TIME hnsRequested = 100000;
        hr = client->Initialize(AUDCLNT_SHAREMODE_SHARED,
            0, hnsRequested, 0, pwfx, nullptr);
        if (FAILED(hr)) {
            client->Release();
            device->Release();
            if (comOwned) CoUninitialize();
            return;
        }

        UINT32 bufferFrameCount;
        client->GetBufferSize(&bufferFrameCount);

        IAudioCaptureClient* capture = nullptr;
        client->GetService(__uuidof(IAudioCaptureClient), (void**)&capture);
        client->Start();

        while (g_running.load(std::memory_order_relaxed)) {
            Sleep(5);
            UINT32 packetLength = 0;
            capture->GetNextPacketSize(&packetLength);
            while (packetLength > 0) {
                float* data;
                UINT32 numFrames;
                DWORD flags;
                capture->GetBuffer((BYTE**)&data, &numFrames, &flags,
                                   nullptr, nullptr);
                if (!(flags & AUDCLNT_BUFFERFLAGS_SILENT))
                    g_ring->write(data, numFrames);
                capture->ReleaseBuffer(numFrames);
                capture->GetNextPacketSize(&packetLength);
            }
        }

        client->Stop();
        capture->Release();
        client->Release();
        device->Release();
        if (comOwned) CoUninitialize();
    } catch (...) {
        // Prevent abort() — silently exit capture thread
    }
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

    try {
        g_thread = std::thread(capture_loop, device);
        return g_thread.joinable() ? 0 : -1;
    } catch (...) {
        g_running.store(false);
        return -1;
    }
}

void platform_audio_stop() {
    g_running.store(false);
    if (g_thread.joinable()) g_thread.join();
    g_ring = nullptr;
}

} // extern "C"
