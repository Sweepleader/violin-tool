import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';

class ViolinApp extends StatelessWidget {
  const ViolinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Violin Practice',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
