import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:violin_app/plugins/tuner/tuner_plugin.dart';
import 'package:violin_app/core/plugin/plugin_registry.dart';
import 'package:violin_app/core/services/providers.dart';
import 'package:violin_app/core/services/database_service.dart';
import '../../test_utils/mock_plugin.dart';

void main() {
  group('TunerPlugin', () {
    late TunerPlugin plugin;
    late ProviderContainer container;
    late AppDatabase db;

    setUp(() async {
      db = await AppDatabase.memory();
      container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWithValue(StubAudioEngine()),
          databaseProvider.overrideWithValue(db),
          llmClientProvider.overrideWithValue(StubLlmClient()),
          traceLoggerProvider.overrideWithValue(StubTraceLogger()),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()),
        ],
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
      await plugin.init(container);
    });

    test('buildView returns a widget', () {
      expect(plugin.buildView(), isA<Widget>());
    });
  });
}
