import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:violin_app/core/plugin/plugin_context.dart';
import 'package:violin_app/core/plugin/plugin_registry.dart';
import 'package:violin_app/core/services/database_service.dart';
import '../../test_utils/mock_plugin.dart';

void main() {
  group('ToolPlugin contract', () {
    test('mock plugin implements all required getters', () {
      final plugin = MockPlugin();
      expect(plugin.id, isNotEmpty);
      expect(plugin.name, isNotEmpty);
      expect(plugin.description, isNotEmpty);
      expect(plugin.icon, isA<IconData>());
      expect(plugin.actions, isEmpty);
    });

    test('init accepts PluginContext', () async {
      final plugin = MockPlugin();
      final db = await AppDatabase.memory();
      final context = PluginContext(
        audio: StubAudioEngine(),
        db: db,
        llm: StubLlmClient(),
        trace: StubTraceLogger(),
        registry: PluginRegistry(),
      );
      await plugin.init(context);
      expect(plugin.initialized, isTrue);
      await db.close();
    });

    test('buildView returns a widget', () {
      final plugin = MockPlugin();
      expect(plugin.buildView(), isA<Widget>());
    });

    test('buildCompactView can return null', () {
      final plugin = MockPlugin();
      expect(plugin.buildCompactView(), isNull);
    });
  });
}
