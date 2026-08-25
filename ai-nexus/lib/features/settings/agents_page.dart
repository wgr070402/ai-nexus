import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/widgets/setting_widgets.dart';

/// 补充配置 · 智能体 / 专家（对齐 UI 设计稿）
class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('智能体 / 专家'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
        children: const [
          SettingGroup(
            children: [
              SettingRow(label: '代码专家', value: '已启用'),
              SettingRow(label: '写作助手', value: '已启用'),
              SettingRow(
                label: '新建智能体',
                value: '+ 添加',
                trailing: SizedBox.shrink(),
              ),
            ],
          ),
          SettingGroup(
            children: [
              SettingRow(label: '角色卡导入', value: 'Silly Tavern'),
            ],
          ),
        ],
      ),
    );
  }
}
