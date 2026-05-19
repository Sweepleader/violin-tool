import 'package:flutter_test/flutter_test.dart';
import 'package:violin_app/core/services/llm_client.dart';

void main() {
  group('LlmClient', () {
    test('LlmConfig has correct defaults for Windows', () {
      final config = LlmConfig.windows();
      expect(config.baseUrl, 'http://localhost:11434');
      expect(config.provider, LlmProvider.ollama);
    });

    test('LlmConfig has correct defaults for Android', () {
      final config = LlmConfig.android();
      expect(config.provider, LlmProvider.openai);
      expect(config.baseUrl, 'https://api.openai.com/v1');
    });

    test('LlmClient can be created with config', () {
      const config = LlmConfig(
        baseUrl: 'http://localhost:11434',
        apiKey: null,
        provider: LlmProvider.ollama,
        model: 'qwen2.5:3b',
      );
      final client = LlmClient(config: config);
      expect(client.config.model, 'qwen2.5:3b');
    });
  });
}
