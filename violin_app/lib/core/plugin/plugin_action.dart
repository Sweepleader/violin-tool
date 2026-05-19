import 'package:flutter/material.dart';

class PluginAction {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final WidgetBuilder? pageBuilder;

  const PluginAction({
    required this.id,
    required this.label,
    required this.icon,
    this.onTap,
    this.pageBuilder,
  });
}
