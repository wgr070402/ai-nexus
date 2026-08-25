import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// DeepSeek Harness · 未配置引导页（对齐 UI 设计稿）
class HarnessSetupPage extends StatelessWidget {
  const HarnessSetupPage({super.key});

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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 闪电图标 72px 圆角20
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.bolt, size: 34, color: AppColors.text),
            ),
            const SizedBox(height: 18),
            const Text(
              'DeepSeek Harness 环境未就绪',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'DeepSeek Harness 依赖本地服务，需先在终端完成初始化，之后即可直接对话。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: AppColors.text2,
              ),
            ),
            const SizedBox(height: 22),
            // 三步引导卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Step(n: '1', text: '打开侧边栏「终端」'),
                  _Step(n: '2', text: '执行 npx @deepseek-ai/dsh web 启动服务'),
                  _Step(n: '3', text: '返回后点下方「检查并开始」'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            // 主按钮：去终端配置（青绿底白字）
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: const Text(
                  '去终端配置',
                  style: TextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 次按钮：检查并开始（灰底 + 边框）
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.card,
                  foregroundColor: AppColors.text,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: Color(0xFFE5E5E7)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: const Text(
                  '检查并开始',
                  style: TextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
            ),
            child: Text(
              n,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: AppFontSize.small,
                height: 1.6,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
