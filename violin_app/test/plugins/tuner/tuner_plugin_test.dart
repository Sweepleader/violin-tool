import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:violin_app/plugins/tuner/tuner_plugin.dart';
import 'package:violin_app/core/plugin/plugin_context.dart';
import 'package:violin_app/core/plugin/plugin_registry.dart';
import 'package:violin_app/core/services/database_service.dart';
import '../../test_utils/mock_plugin.dart';

void main() {
  group('TunerPlugin', () {
    late TunerPlugin plugin;
    late PluginContext context;
    late AppDatabase db;

    setUp(() async {
      db = await AppDatabase.memory();
      context = PluginContext(
        audio: StubAudioEngine(),
        db: db,
        llm: StubLlmClient(),
        trace: StubTraceLogger(),
        registry: PluginRegistry(),
      );
      plugin = TunerPlugin();
    });

    tearDown(() async {
      await db.close();
    });

    test('has correct id', () {
      expect(plugin.id, 'tuner');
    });

    test('has correct name', () {
      expect(plugin.name, 'Tuner');
    });

    test('init initializes audio engine', () async {
      await plugin.init(context);
    });

    test('buildView returns a widget', () {
      expect(plugin.buildView(), isA<Widget>());
    });
  });
}
