import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/widgets/setting_widgets.dart';

/// 补充配置 · 群聊（对齐 UI 设计稿）
class GroupChatSettingsPage extends StatefulWidget {
  const GroupChatSettingsPage({super.key});

  @override
  State<GroupChatSettingsPage> createState() => _GroupChatSettingsPageState();
}

class _GroupChatSettingsPageState extends State<GroupChatSettingsPage> {
  int _mode = 0; // 0 并行 / 1 讨论式

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('群聊'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
        children: [
          SettingGroup(
            children: [
              OptionRow(
                label: '并行',
                hint: '成员同时回复',
                selected: _mode == 0,
                onTap: () => setState(() => _mode = 0),
              ),
              OptionRow(
                label: '讨论式',
                hint: '按顺序轮流发言',
                selected: _mode == 1,
                onTap: () => setState(() => _mode = 1),
              ),
            ],
          ),
          const SettingGroup(
            children: [
              SettingRow(label: '成员上限', value: '10', trailing: SizedBox.shrink()),
              SettingRow(label: '模型库'),
              SettingRow(label: '智能体库'),
            ],
          ),
        ],
      ),
    );
  }
}
