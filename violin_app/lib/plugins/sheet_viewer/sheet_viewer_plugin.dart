import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plugin/tool_plugin.dart';
import '../../core/plugin/plugin_action.dart';
import 'sheet_viewer_page.dart';

class SheetViewerPlugin extends ToolPlugin {
  @override
  String get id => 'sheet_viewer';
  @override
  String get name => 'Sheet';
  @override
  String get description => 'View and follow sheet music';
  @override
  IconData get icon => Icons.library_music;
  @override
  List<PluginAction> get actions => const [];

  @override
  Future<void> init(ProviderContainer container) async {}

  @override
  Widget buildView() => const SheetViewerPage();
  @override
  Widget? buildCompactView() => null;
}
