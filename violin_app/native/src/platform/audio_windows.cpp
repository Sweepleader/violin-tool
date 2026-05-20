// Stub — real WASAPI implementation in Task 3
extern "C" {
    int platform_audio_init() { return 0; }
    int platform_audio_start() { return 0; }
    void platform_audio_stop() {}
}
