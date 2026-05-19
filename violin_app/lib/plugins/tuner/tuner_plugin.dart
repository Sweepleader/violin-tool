import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/plugin/tool_plugin.dart';
import '../../core/plugin/plugin_context.dart';
import '../../core/plugin/plugin_action.dart';
import 'tuner_page.dart';

class TunerPlugin extends ToolPlugin {
  PluginContext? _context;
  Timer? _pitchTimer;

  @override
  String get id => 'tuner';

  @override
  String get name => 'Tuner';

  @override
  String get description => 'Real-time chromatic tuner for violin';

  @override
  IconData get icon => Icons.tune;

  @override
  List<PluginAction> get actions => [
        PluginAction(
          id: 'quick_tune_a',
          label: 'Tune A',
          icon: Icons.music_note,
          onTap: () {},
        ),
      ];

  @override
  Future<void> init(PluginContext context) async {
    _context = context;
    await context.audio.initialize();
  }

  @override
  Widget buildView() {
    return TunerPage(plugin: this);
  }

  @override
  Widget? buildCompactView() {
    return const Center(child: Text('Tuner - compact view TBD'));
  }

  @override
  Future<void> dispose() async {
    _pitchTimer?.cancel();
    await _context?.audio.dispose();
    super.dispose();
  }
}
