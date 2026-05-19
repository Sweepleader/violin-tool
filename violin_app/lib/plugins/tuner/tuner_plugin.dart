import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plugin/tool_plugin.dart';
import '../../core/plugin/plugin_action.dart';
import '../../core/services/providers.dart';
import 'tuner_page.dart';

class TunerPlugin extends ToolPlugin {
  ProviderContainer? _container;

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
  Future<void> init(ProviderContainer container) async {
    _container = container;
    final audio = container.read(audioEngineProvider);
    await audio.initialize();
  }

  @override
  Widget buildView() {
    return const TunerPage();
  }

  @override
  Widget? buildCompactView() {
    return const Center(child: Text('Tuner - compact view TBD'));
  }

  @override
  Future<void> dispose() async {
    final audio = _container?.read(audioEngineProvider);
    await audio?.dispose();
    _container = null;
    super.dispose();
  }
}
