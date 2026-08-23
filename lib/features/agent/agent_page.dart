import 'package:flutter/material.dart';

import '../../core/widgets/under_construction.dart';

/// Agent 板块。Phase 3 起实现。
class AgentPage extends StatelessWidget {
  const AgentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnderConstruction(
      title: 'Agent',
      icon: Icons.smart_toy_outlined,
      description: '创建、编辑与管理你的 AI 专家团队。',
    );
  }
}
