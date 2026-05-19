import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'core/plugin/plugin_registry.dart';
import 'core/plugin/plugin_context.dart';
import 'core/services/database_service.dart';
import 'core/services/audio_engine_stub.dart';
import 'core/services/llm_client.dart';
import 'core/services/trace_logger.dart';
import 'plugins/tuner/tuner_plugin.dart';
import 'features/shell/plugin_toolbar.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appDir = await getApplicationDocumentsDirectory();
  final db = await AppDatabase.open(appDir.path);
  final audio = AudioEngineStub();
  final llmConfig = LlmConfig.windows();
  final llm = LlmClient(config: llmConfig);
  final trace = TraceLogger();
  final registry = PluginRegistry();

  final context = PluginContext(
    audio: audio,
    db: db,
    llm: llm,
    trace: trace,
    registry: registry,
  );

  final tuner = TunerPlugin();
  await tuner.init(context);
  registry.register(tuner);

  runApp(
    ProviderScope(
      overrides: [
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const ViolinApp(),
    ),
  );
}
