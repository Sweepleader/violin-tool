import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plugin/tool_plugin.dart';
import '../../core/plugin/plugin_action.dart';
import 'metronome_page.dart';

class MetronomePlugin extends ToolPlugin {
  @override
  String get id => 'metronome';
  @override
  String get name => 'Metronome';
  @override
  String get description => 'Visual and audio metronome';
  @override
  IconData get icon => Icons.timer;
  @override
  List<PluginAction> get actions => const [];

  @override
  Future<void> init(ProviderContainer container) async {}

  @override
  Widget buildView() => const MetronomePage();

  @override
  Widget? buildCompactView() => null;
}
