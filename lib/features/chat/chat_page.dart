import 'package:flutter/material.dart';

import '../../core/widgets/under_construction.dart';

/// 会话板块（单聊 / 群聊）。Phase 2 起实现。
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnderConstruction(
      title: '会话',
      icon: Icons.chat_bubble_outline,
      description: '单聊、群聊与 Multi-Agent 协作将在后续阶段接入。',
    );
  }
}
