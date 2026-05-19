import '../services/database_service.dart';
import '../services/audio_engine_stub.dart';
import '../services/llm_client.dart';
import '../services/trace_logger.dart';
import 'plugin_registry.dart';

class PluginContext {
  final AudioEngineStub audio;
  final AppDatabase db;
  final LlmClient llm;
  final TraceLogger trace;
  final PluginRegistry registry;

  const PluginContext({
    required this.audio,
    required this.db,
    required this.llm,
    required this.trace,
    required this.registry,
  });
}
