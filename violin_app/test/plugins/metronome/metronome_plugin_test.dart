import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:violin_app/plugins/metronome/metronome_plugin.dart';
import 'package:violin_app/core/plugin/plugin_registry.dart';
import 'package:violin_app/core/services/providers.dart';
import 'package:violin_app/core/services/audio_engine.dart';
import 'package:violin_app/core/services/database_service.dart';
import '../../test_utils/mock_plugin.dart';

void main() {
  group('MetronomePlugin', () {
    late MetronomePlugin plugin;
    late ProviderContainer container;

    setUp(() async {
      container = ProviderContainer(overrides: [
        audioEngineProvider.overrideWithValue(StubAudioEngine()),
        databaseProvider.overrideWithValue(await AppDatabase.memory()),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()),
      ]);
      addTearDown(() => container.dispose());
      plugin = MetronomePlugin();
      await plugin.init(container);
    });

    test('has correct id', () {
      expect(plugin.id, 'metronome');
    });

    test('has correct name', () {
      expect(plugin.name, 'Metronome');
    });

    test('buildView returns a widget', () {
      expect(plugin.buildView(), isA<Widget>());
    });
  });
}
