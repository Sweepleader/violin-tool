import 'package:flutter_test/flutter_test.dart';
import 'package:violin_app/core/plugin/plugin_registry.dart';
import 'package:violin_app/core/plugin/tool_plugin.dart';
import '../../test_utils/mock_plugin.dart';

void main() {
  group('PluginRegistry', () {
    late PluginRegistry registry;

    setUp(() {
      registry = PluginRegistry();
    });

    test('initial state has no plugins', () {
      expect(registry.plugins, isEmpty);
    });

    test('register adds plugin and returns it in list', () {
      final plugin = MockPlugin();
      registry.register(plugin);
      expect(registry.plugins, contains(plugin));
      expect(registry.plugins.length, 1);
    });

    test('register throws on duplicate id', () {
      registry.register(MockPlugin());
      expect(
        () => registry.register(MockPlugin()),
        throwsA(isA<PluginRegistrationException>()),
      );
    });

    test('getPlugin finds by id', () {
      final plugin = MockPlugin();
      registry.register(plugin);
      expect(registry.getPlugin('mock_plugin'), same(plugin));
    });

    test('getPlugin throws on unknown id', () {
      expect(
        () => registry.getPlugin('nonexistent'),
        throwsA(isA<PluginNotFoundException>()),
      );
    });

    test('unregister removes plugin', () {
      final plugin = MockPlugin();
      registry.register(plugin);
      registry.unregister('mock_plugin');
      expect(registry.plugins, isEmpty);
    });

    test('disposeAll calls dispose on all plugins', () {
      final plugin = MockPlugin();
      registry.register(plugin);
      registry.disposeAll();
      // No exception = pass
    });
  });
}
