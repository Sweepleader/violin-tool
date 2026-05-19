import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/providers.dart';
import 'plugin_toolbar.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  String? _activePluginId;

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(pluginRegistryProvider);
    final plugins = registry.plugins;

    final activePlugin = _activePluginId != null
        ? registry.getPlugin(_activePluginId!)
        : null;

    return Scaffold(
      body: activePlugin != null
          ? activePlugin.buildView()
          : const Center(child: Text('Select a tool to begin')),
      bottomNavigationBar: plugins.isNotEmpty
          ? PluginToolbar(
              selectedPluginId: _activePluginId,
              onPluginSelected: (id) => setState(() => _activePluginId = id),
            )
          : null,
    );
  }
}
