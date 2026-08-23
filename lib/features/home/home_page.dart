import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/app_constants.dart';

/// 首页：欢迎语 + 快捷操作 + 最近会话/Agent 概览。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            _logoMark(),
            const SizedBox(width: 10),
            const Text(AppConstants.appName),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surfaceLight,
              child: const Icon(Icons.person_outline,
                  size: 18, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          _GreetingCard(),
          const SizedBox(height: 20),
          const Text('快捷操作',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          const _QuickActions(),
          const SizedBox(height: 24),
          _SectionHeader(title: '最近会话', trailing: '查看全部'),
          const SizedBox(height: 12),
          const _EmptyState(
            icon: Icons.forum_outlined,
            title: '还没有会话',
            subtitle: '点击上方「快捷操作」开启你的第一个 AI 会话',
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: '我的 Agent', trailing: '管理'),
          const SizedBox(height: 12),
          const _EmptyState(
            icon: Icons.smart_toy_outlined,
            title: '还没有 Agent',
            subtitle: '创建专属 AI 专家，组建你的智能团队',
          ),
        ],
      ),
    );
  }

  Widget _logoMark() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.hub_outlined, size: 18, color: Colors.white),
    );
  }
}

/// 顶部欢迎卡片（渐变强调）。
class _GreetingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF2A1E5C), Color(0xFF0E2A4A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('欢迎回来 👋',
              style: TextStyle(
                  fontSize: 14, color: AppColors.primaryLight)),
          const SizedBox(height: 6),
          const Text('今天想做什么？',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Text(AppConstants.appTagline,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// 快捷操作网格。
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    const List<_QuickActionData> actions = <_QuickActionData>[
      _QuickActionData(Icons.chat_bubble_outline, '单聊', '与单个模型对话'),
      _QuickActionData(Icons.groups_outlined, '群聊', '多 Agent 协作'),
      _QuickActionData(Icons.smart_toy_outlined, 'Agent', '创建 AI 专家'),
      _QuickActionData(Icons.terminal_outlined, 'Terminal', '运行命令'),
    ];

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: _QuickActionCard(actions[0])),
            const SizedBox(width: 12),
            Expanded(child: _QuickActionCard(actions[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(child: _QuickActionCard(actions[2])),
            const SizedBox(width: 12),
            Expanded(child: _QuickActionCard(actions[3])),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard(this.data);
  final _QuickActionData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => debugPrint('快捷操作点击：${data.title}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: AppColors.primaryLight, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(data.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

/// 区块标题行。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        Text(trailing,
            style: const TextStyle(fontSize: 13, color: AppColors.accent)),
      ],
    );
  }
}

/// 空状态占位。
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 32, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
