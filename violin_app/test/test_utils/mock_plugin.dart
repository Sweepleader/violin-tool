import 'package:flutter/material.dart';
import 'package:violin_app/core/plugin/tool_plugin.dart';
import 'package:violin_app/core/plugin/plugin_context.dart';
import 'package:violin_app/core/plugin/plugin_action.dart';
import 'package:violin_app/core/services/audio_engine_stub.dart';
import 'package:violin_app/core/services/database_service.dart';
import 'package:violin_app/core/services/llm_client.dart';
import 'package:violin_app/core/services/trace_logger.dart';
import 'package:violin_app/core/plugin/plugin_registry.dart';

class MockPlugin extends ToolPlugin {
  bool initialized = false;

  @override
  String get id => 'mock_plugin';

  @override
  String get name => 'Mock Plugin';

  @override
  String get description => 'A mock plugin for testing';

  @override
  IconData get icon => Icons.music_note;

  @override
  List<PluginAction> get actions => const [];

  @override
  Future<void> init(PluginContext context) async {
    initialized = true;
  }

  @override
  Widget buildView() => const Placeholder();

  @override
  Widget? buildCompactView() => null;
}

class StubAudioEngine extends AudioEngineStub {
  Future<void> start() async {}
  Future<void> stop() async {}
  double get frequency => 440.0;
}

class StubDatabase extends AppDatabase {
  Future<void> initialize() async {}
}

class StubLlmClient extends LlmClient {}

class StubTraceLogger extends TraceLogger {
  void log(String event, {Map<String, dynamic>? data}) {}
}

class StubRegistry extends PluginRegistry {
  void register(dynamic plugin) {}
}
