import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'plugin_action.dart';

abstract class ToolPlugin {
  String get id;
  String get name;
  String get description;
  IconData get icon;

  Future<void> init(ProviderContainer container);
  Widget buildView();
  Widget? buildCompactView();
  List<PluginAction> get actions;
  Future<void> dispose() async {}
}
