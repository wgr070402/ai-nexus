import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/widgets/chat_bubble.dart';
import '../home/widgets/composer.dart';

/// DeepSeek Harness · 已配置对话页（对齐 UI 设计稿）
class HarnessChatPage extends StatelessWidget {
  const HarnessChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('DeepSeek Harness'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ChatBubble(text: '帮我查一下今天上海的天气', isUser: true),
                SizedBox(height: 12),
                ToolCallTag(tool: 'web_search'),
                SizedBox(height: 12),
                ChatBubble(text: '上海今天多云，24–31℃，午后有小雨，记得带伞。'),
              ],
            ),
          ),
          // 底部输入栏（不显示模型切换）
          const Composer(placeholder: '发消息...', showModelChip: false),
        ],
      ),
    );
  }
}
