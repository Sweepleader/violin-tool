class AudioEngineStub {
  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    _initialized = true;
  }

  Future<double> getCurrentFrequency() async {
    if (!_initialized) throw StateError('AudioEngine not initialized');
    return 440.0;
  }

  Future<void> dispose() async {
    _initialized = false;
  }
}
