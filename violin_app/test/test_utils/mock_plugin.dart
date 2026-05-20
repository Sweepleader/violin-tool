import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:violin_app/core/plugin/tool_plugin.dart';
import 'package:violin_app/core/plugin/plugin_action.dart';
import 'package:violin_app/core/services/audio_engine.dart';
import 'package:violin_app/core/services/llm_client.dart';
import 'package:violin_app/core/services/trace_logger.dart';

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
  Future<void> init(ProviderContainer container) async {
    initialized = true;
  }

  @override
  Widget buildView() => const Placeholder();

  @override
  Widget? buildCompactView() => null;
}

class StubAudioEngine extends AudioEngine {
  StubAudioEngine() : super.test();
}

class StubLlmClient extends LlmClient {
  StubLlmClient() : super(config: LlmConfig.windows());
}

class StubTraceLogger extends TraceLogger {}
