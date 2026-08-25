import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/widgets/home_bar.dart';
import '../../core/widgets/status_bar.dart';

/// 终端主界面（深色代码风格，对齐 UI 设计稿「终端 · 主界面」）
/// M1 阶段静态还原；M5 阶段接真实 proot Ubuntu 24.04。
class TerminalPage extends StatelessWidget {
  const TerminalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.termBg,
      body: Column(
        children: [
          const StatusBar(dark: true),
          _TermHead(),
          Expanded(child: _TermBody()),
          const HomeBar(dark: true),
        ],
      ),
    );
  }
}

/// 顶栏：#151517，左「Ubuntu 24.04」+ 青绿状态点，右齿轮
class _TermHead extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.termHead,
        border: Border(bottom: BorderSide(color: Color(0xFF232326))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'Ubuntu 24.04',
                style: TextStyle(
                  fontSize: AppFontSize.small,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text3,
                ),
              ),
            ],
          ),
          const Icon(Icons.settings_outlined, size: 20, color: AppColors.text2),
        ],
      ),
    );
  }
}

class _TermBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _prompt(cmd: 'pwd'),
          const _Out('  /home/user'),
          _blank(),
          _prompt(cmd: 'ls -la'),
          const _Out('  total 24'),
          const _Out('  drwxr-xr-x  6 user user 4096 Aug 25 09:41  ', dir: '.'),
          const _Out('  drwxr-xr-x  4 root root 4096 Aug 25 09:40  ', dir: '..'),
          const _Out('  drwxr-xr-x  2 user user 4096 Aug 25 09:41  ', dir: 'projects'),
          const _Out('  -rw-r--r--  1 user user  220 Aug 25 09:40 .bashrc'),
          _blank(),
          _prompt(cmd: 'python3 --version'),
          const _Out('  Python 3.12.3'),
          _blank(),
          _prompt(cmd: 'npx @deepseek-ai/dsh web'),
          const _Out('  DeepSeek Harness server ready → ', highlight: 'http://127.0.0.1:3080'),
          _blank(),
          const _Out('  ── 环境状态检测 ──'),
          const _Out('  ✓ Python  3.12.3', ok: true),
          const _Out('  ✓ Node    20.11.0', ok: true),
          const _Out('  ✓ Shell   bash 5.2', ok: true),
          const _Out('  ✓ Harness 127.0.0.1:3080', ok: true),
          const _Out('  ✗ Codex   未安装', fail: true),
          _blank(),
          _cursor(),
        ],
      ),
    );
  }

  Widget _prompt({required String cmd}) {
    const promptStyle = TextStyle(color: AppColors.teal);
    return Text.rich(
      TextSpan(children: [
        const TextSpan(text: 'user@nexus', style: TextStyle(color: AppColors.termUser)),
        TextSpan(text: ':~\$ ', style: promptStyle),
        TextSpan(text: cmd, style: const TextStyle(color: Color(0xFFF2F2F4))),
      ]),
      style: _mono,
    );
  }

  Widget _blank() => const SizedBox(height: 10);

  Widget _cursor() {
    return Row(
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'user@nexus', style: TextStyle(color: AppColors.termUser)),
            TextSpan(text: ':~\$ ', style: const TextStyle(color: AppColors.teal)),
          ]),
          style: _mono,
        ),
        _BlinkingCursor(),
      ],
    );
  }
}

const TextStyle _mono = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12.5,
  height: 1.85,
  color: AppColors.termText,
);

class _Out extends StatelessWidget {
  const _Out(this.text, {this.dir, this.highlight, this.ok = false, this.fail = false});

  final String text;
  final String? dir;
  final String? highlight;
  final bool ok;
  final bool fail;

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.termOut;
    if (ok) color = AppColors.teal;
    if (fail) color = AppColors.red;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text, style: TextStyle(color: color)),
        if (dir != null)
          TextSpan(text: dir, style: const TextStyle(color: AppColors.termDir)),
        if (highlight != null)
          TextSpan(text: highlight, style: const TextStyle(color: AppColors.termDir)),
      ]),
      style: _mono,
    );
  }
}

/// 闪烁光标
class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        width: 8,
        height: 15,
        margin: const EdgeInsets.only(left: 3),
        color: AppColors.teal,
      ),
    );
  }
}
