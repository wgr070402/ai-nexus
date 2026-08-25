import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// 设置页（对齐 UI 设计稿「页面四 · 设置页」）
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
        children: const [
          _Group(
            children: [
              _Row(label: '记忆库'),
            ],
          ),
          _Group(
            children: [
              _ThemeSeg(),
              _Row(label: '语言', value: '跟随系统'),
              _Row(label: '字体大小'),
            ],
          ),
          _Group(
            children: [
              _Row(label: '使用帮助'),
            ],
          ),
          _Group(
            children: [
              _Row(label: '消息通知设置', value: '已开启'),
            ],
          ),
          _Group(
            children: [
              _Row(label: '分享日志', value: '按时间范围导出'),
              _Row(label: '清除日志'),
              _Row(label: '意见反馈'),
            ],
          ),
        ],
      ),
    );
  }
}

/// 分组容器：#F7F7F7 圆角 16px 带阴影
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadow.card,
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFECECEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: AppFontSize.body, color: AppColors.text),
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: const TextStyle(fontSize: 14, color: AppColors.text2),
            ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.text3),
        ],
      ),
    );
  }
}

/// 主题分段控件：系统/浅色/深色
class _ThemeSeg extends StatefulWidget {
  const _ThemeSeg();

  @override
  State<_ThemeSeg> createState() => _ThemeSegState();
}

class _ThemeSegState extends State<_ThemeSeg> {
  int _selected = 0; // 0 系统 / 1 浅色 / 2 深色

  @override
  Widget build(BuildContext context) {
    const items = ['系统', '浅色', '深色'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '主题',
              style: TextStyle(fontSize: AppFontSize.body, color: AppColors.text),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFE7E7EA),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              children: List.generate(items.length, (i) {
                final on = _selected == i;
                return GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: on ? AppColors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: on
                          ? const [
                              BoxShadow(
                                color: Color(0x29000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      items[i],
                      style: TextStyle(
                        fontSize: AppFontSize.small,
                        color: on ? AppColors.text : AppColors.text2,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
