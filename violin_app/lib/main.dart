import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/plugin/plugin_registry.dart';
import 'core/services/database_service.dart';
import 'core/services/audio_engine_stub.dart';
import 'core/services/llm_client.dart';
import 'core/services/trace_logger.dart';
import 'core/services/providers.dart';
import 'plugins/tuner/tuner_plugin.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await AppDatabase.memory();
  final audio = AudioEngineStub();
  final llmConfig = LlmConfig.windows();
  final llm = LlmClient(config: llmConfig);
  final trace = TraceLogger();
  final registry = PluginRegistry();

  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      audioEngineProvider.overrideWithValue(audio),
      llmClientProvider.overrideWithValue(llm),
      traceLoggerProvider.overrideWithValue(trace),
      pluginRegistryProvider.overrideWithValue(registry),
    ],
  );

  final tuner = TunerPlugin();
  await tuner.init(container);
  registry.register(tuner);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ViolinApp(),
    ),
  );
}
