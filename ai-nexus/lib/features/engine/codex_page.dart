import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/widgets/chat_bubble.dart';
import '../../core/widgets/code_diff.dart';
import '../home/widgets/composer.dart';

/// Codex · 已配置编码工作台（对齐 UI 设计稿）
class CodexPage extends StatelessWidget {
  const CodexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Codex'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ChatBubble(text: '给 add(a, b) 写单元测试', isUser: true),
                SizedBox(height: 12),
                ChatBubble(text: '已生成测试，变更如下：'),
                CodeDiffBlock(
                  lines: [
                    DiffLine(' def add(a, b):', DiffLineType.context),
                    DiffLine('     return a + b', DiffLineType.context),
                    DiffLine('', DiffLineType.context),
                    DiffLine('+def test_add():', DiffLineType.add),
                    DiffLine('+    assert add(1, 2) == 3', DiffLineType.add),
                    DiffLine('+    assert add(-1, 1) == 0', DiffLineType.add),
                  ],
                ),
                SizedBox(height: 8),
                _ActionBar(),
              ],
            ),
          ),
          const Composer(placeholder: '描述代码任务...', showModelChip: false),
        ],
      ),
    );
  }
}

/// 接受变更 / 拒绝
class _ActionBar extends StatelessWidget {
  const _ActionBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: const Text(
              '接受变更',
              style: TextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.text,
              padding: const EdgeInsets.symmetric(vertical: 11),
              side: const BorderSide(color: Color(0xFFE5E5E7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: const Text(
              '拒绝',
              style: TextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
