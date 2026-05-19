import 'package:flutter/material.dart';
import 'plugin_context.dart';
import 'plugin_action.dart';

abstract class ToolPlugin {
  String get id;
  String get name;
  String get description;
  IconData get icon;

  Future<void> init(PluginContext context);
  Widget buildView();
  Widget? buildCompactView();
  List<PluginAction> get actions;
  Future<void> dispose() async {}
}
