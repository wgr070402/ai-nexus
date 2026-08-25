import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// 代码 diff 行类型
enum DiffLineType { context, add, delete }

class DiffLine {
  const DiffLine(this.text, this.type);
  final String text;
  final DiffLineType type;
}

/// 代码 diff 块（对齐 UI 设计稿「Codex · 编码工作台」）
/// 上下文灰 / + 新增青绿底 / - 删除红底
class CodeDiffBlock extends StatelessWidget {
  const CodeDiffBlock({super.key, required this.lines});

  final List<DiffLine> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((l) {
          final Color color;
          final Color bg;
          switch (l.type) {
            case DiffLineType.context:
              color = AppColors.text2;
              bg = Colors.transparent;
              break;
            case DiffLineType.add:
              color = const Color(0xFF0AA77E);
              bg = const Color(0x1A00C896);
              break;
            case DiffLineType.delete:
              color = const Color(0xFFE5484D);
              bg = const Color(0x1AE5484D);
              break;
          }
          return Container(
            width: double.infinity,
            color: bg,
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
              l.text,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.75,
                color: color,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
