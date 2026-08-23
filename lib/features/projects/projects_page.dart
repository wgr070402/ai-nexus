import 'package:flutter/material.dart';

import '../../core/widgets/under_construction.dart';

/// 项目板块。Phase 9 起实现。
class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnderConstruction(
      title: '项目',
      icon: Icons.folder_outlined,
      description: '项目管理、文件、Git 与活动日志将在后续阶段接入。',
    );
  }
}
