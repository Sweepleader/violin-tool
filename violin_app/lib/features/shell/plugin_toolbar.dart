import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plugin/plugin_registry.dart';

final pluginRegistryProvider = Provider<PluginRegistry>((ref) {
  throw UnimplementedError('PluginRegistry must be overridden in app setup');
});

class PluginToolbar extends ConsumerWidget {
  final String? selectedPluginId;
  final ValueChanged<String> onPluginSelected;

  const PluginToolbar({
    super.key,
    required this.selectedPluginId,
    required this.onPluginSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(pluginRegistryProvider);
    final plugins = registry.plugins;

    return NavigationBar(
      selectedIndex: plugins.indexWhere((p) => p.id == selectedPluginId),
      onDestinationSelected: (index) {
        if (index < plugins.length) {
          onPluginSelected(plugins[index].id);
        }
      },
      destinations: plugins
          .map((p) => NavigationDestination(
                icon: Icon(p.icon),
                selectedIcon: Icon(p.icon, fill: 1),
                label: p.name,
              ))
          .toList(),
    );
  }
}
