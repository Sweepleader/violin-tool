enum LlmProvider { ollama, openai }

class LlmConfig {
  final String baseUrl;
  final String? apiKey;
  final LlmProvider provider;
  final String model;

  const LlmConfig({
    required this.baseUrl,
    this.apiKey,
    required this.provider,
    required this.model,
  });

  factory LlmConfig.windows() => const LlmConfig(
        baseUrl: 'http://localhost:11434',
        apiKey: null,
        provider: LlmProvider.ollama,
        model: 'qwen2.5:3b',
      );

  factory LlmConfig.android() => const LlmConfig(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: null,
        provider: LlmProvider.openai,
        model: 'gpt-4o-mini',
      );
}

class LlmClient {
  final LlmConfig config;

  LlmClient({required this.config});

  Future<String> generate(String prompt) async {
    throw UnimplementedError('LLM client not connected');
  }

  Future<String> critique(String content) async {
    throw UnimplementedError('LLM client not connected');
  }
}
