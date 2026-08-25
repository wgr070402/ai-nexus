import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// 环境状态面板：三态显示（运行中/未配置/配置失败），对齐 UI 设计稿
class EnvStatusPage extends StatelessWidget {
  const EnvStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('环境状态'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _EnvCard(
            icon: Icons.code,
            iconColor: Color(0xFF306998),
            name: 'Python',
            version: '3.12.3',
            status: EnvStatus.running,
          ),
          _EnvCard(
            icon: Icons.circle,
            iconColor: Color(0xFF339933),
            name: 'Node.js',
            version: '20.11.0',
            status: EnvStatus.running,
          ),
          _EnvCard(
            icon: Icons.terminal,
            iconColor: Color(0xFF4EAA25),
            name: 'Shell',
            version: 'bash 5.2',
            status: EnvStatus.running,
          ),
          _EnvCard(
            icon: Icons.bolt,
            iconColor: Color(0xFF00C896),
            name: 'DeepSeek Harness',
            version: '127.0.0.1:3080',
            status: EnvStatus.running,
          ),
          _EnvCard(
            icon: Icons.code_off,
            iconColor: Color(0xFF1A1A1A),
            name: 'Codex',
            version: '未安装',
            status: EnvStatus.unconfigured,
          ),
          _EnvCard(
            icon: Icons.diamond_outlined,
            iconColor: Color(0xFF8B5CF6),
            name: 'Ruby',
            version: '版本不兼容',
            status: EnvStatus.failed,
          ),
        ],
      ),
    );
  }
}

enum EnvStatus { running, unconfigured, failed }

class _EnvCard extends StatelessWidget {
  const _EnvCard({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.version,
    required this.status,
  });

  final IconData icon;
  final Color iconColor;
  final String name;
  final String version;
  final EnvStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // 彩色图标 36px 圆角10
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  version,
                  style: const TextStyle(fontSize: AppFontSize.tiny, color: AppColors.text2),
                ),
              ],
            ),
          ),
          _StatusLabel(status: status),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final EnvStatus status;

  @override
  Widget build(BuildContext context) {
    final Color dot;
    final Color txt;
    final String label;
    final bool showAction;
    switch (status) {
      case EnvStatus.running:
        dot = AppColors.teal;
        txt = AppColors.teal;
        label = '运行中';
        showAction = false;
        break;
      case EnvStatus.unconfigured:
        dot = AppColors.text3;
        txt = AppColors.text3;
        label = '未配置';
        showAction = true;
        break;
      case EnvStatus.failed:
        dot = AppColors.red;
        txt = AppColors.red;
        label = '配置失败';
        showAction = false;
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.small,
            fontWeight: FontWeight.w600,
            color: txt,
          ),
        ),
        if (showAction) ...[
          const SizedBox(width: 8),
          const Text(
            '去配置',
            style: TextStyle(
              fontSize: AppFontSize.small,
              fontWeight: FontWeight.w500,
              color: AppColors.blue,
            ),
          ),
        ],
      ],
    );
  }
}
