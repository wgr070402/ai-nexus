import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';

/// 侧边栏：281px 宽，右圆角 46px，8px 右阴影（对齐 UI 设计稿「页面二 · 侧边栏」）
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 281,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(AppRadius.drawer),
        ),
        boxShadow: AppShadow.drawer,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：头像 + 齿轮
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '咖',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.go('/settings'),
                    child: const Icon(Icons.settings_outlined, size: 24, color: AppColors.text),
                  ),
                ],
              ),
            ),
            // 菜单
            _MenuItem(
              icon: Icons.person_outline,
              label: '专家',
              onTap: () => context.go('/settings/agents'),
            ),
            _MenuItem(icon: Icons.folder_outlined, label: '项目', onTap: () {}),
            _MenuItem(icon: Icons.terminal, label: '终端', onTap: () {}),
            _MenuItem(
              icon: Icons.bolt,
              label: 'DeepSeek Harness',
              hasStatus: true,
              ready: false,
              onTap: () => context.go('/engine/harness-setup'),
            ),
            _MenuItem(
              icon: Icons.code,
              label: 'Codex',
              hasStatus: true,
              ready: true,
              onTap: () => context.go('/engine/codex'),
            ),
            _MenuItem(icon: Icons.groups_outlined, label: '群聊', onTap: () {}),
            // 分隔线
            Container(
              height: 1,
              color: AppColors.divider,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            // 任务区
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    '任务',
                    style: TextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    '完成编辑',
                    style: TextStyle(
                      fontSize: AppFontSize.small,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.add, size: 20, color: AppColors.teal),
                    SizedBox(width: 10),
                    Text(
                      '新建任务',
                      style: TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  '暂无云端任务',
                  style: TextStyle(fontSize: 14, color: AppColors.text3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.hasStatus = false,
    this.ready = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool hasStatus;
  final bool ready;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.text),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 16, color: AppColors.text),
                ),
              ),
              if (hasStatus) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: ready ? AppColors.teal : AppColors.text3,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              const Icon(Icons.chevron_right, size: 18, color: AppColors.text3),
            ],
          ),
        ),
      ),
    );
  }
}
