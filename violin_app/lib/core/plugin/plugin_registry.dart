import 'tool_plugin.dart';

class PluginRegistrationException implements Exception {
  final String message;
  PluginRegistrationException(this.message);

  @override
  String toString() => 'PluginRegistrationException: $message';
}

class PluginNotFoundException implements Exception {
  final String message;
  PluginNotFoundException(this.message);

  @override
  String toString() => 'PluginNotFoundException: $message';
}

class PluginRegistry {
  final Map<String, ToolPlugin> _plugins = {};

  List<ToolPlugin> get plugins => _plugins.values.toList();

  void register(ToolPlugin plugin) {
    if (_plugins.containsKey(plugin.id)) {
      throw PluginRegistrationException(
        'Plugin with id "${plugin.id}" is already registered',
      );
    }
    _plugins[plugin.id] = plugin;
  }

  ToolPlugin getPlugin(String id) {
    final plugin = _plugins[id];
    if (plugin == null) {
      throw PluginNotFoundException('No plugin found with id "$id"');
    }
    return plugin;
  }

  void unregister(String id) {
    _plugins.remove(id);
  }

  Future<void> disposeAll() async {
    for (final plugin in _plugins.values) {
      await plugin.dispose();
    }
    _plugins.clear();
  }
}
