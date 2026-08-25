import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class AiNexusApp extends StatelessWidget {
  const AiNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AI Nexus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
