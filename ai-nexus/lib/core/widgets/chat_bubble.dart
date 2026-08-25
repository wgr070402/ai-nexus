import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// 聊天气泡（对齐 UI 设计稿）
/// 用户：青绿底白字，右下角圆角 6px
/// AI：灰底黑字，左下角圆角 6px
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.text, this.isUser = false});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.teal : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 16),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: isUser ? AppColors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}

/// 工具调用标签（如「调用工具：web_search」）
class ToolCallTag extends StatelessWidget {
  const ToolCallTag({super.key, required this.tool});

  final String tool;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, size: 16, color: AppColors.text2),
            const SizedBox(width: 6),
            Text(
              '调用工具：$tool',
              style: const TextStyle(fontSize: AppFontSize.tiny, color: AppColors.text2),
            ),
          ],
        ),
      ),
    );
  }
}
