import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../plugin/plugin_registry.dart';
import 'database_service.dart';
import 'audio_engine.dart';
import 'llm_client.dart';
import 'trace_logger.dart';

final pluginRegistryProvider = Provider<PluginRegistry>((ref) {
  throw UnimplementedError('PluginRegistry must be overridden in app setup');
});

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Database must be overridden in app setup');
});

final audioEngineProvider = Provider<AudioEngine>((ref) {
  throw UnimplementedError('AudioEngine must be overridden in app setup');
});

final llmClientProvider = Provider<LlmClient>((ref) {
  throw UnimplementedError('LlmClient must be overridden in app setup');
});

final traceLoggerProvider = Provider<TraceLogger>((ref) {
  throw UnimplementedError('TraceLogger must be overridden in app setup');
});
