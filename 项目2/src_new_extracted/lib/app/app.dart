import 'package:flutter/material.dart';

import '../features/home/home_shell.dart';
import 'theme.dart';

/// 应用根组件：装配主题与入口页面。
class AiNexusApp extends StatelessWidget {
  const AiNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Nexus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const HomeShell(),
    );
  }
}
