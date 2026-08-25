import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/widgets/setting_widgets.dart';

/// 补充配置 · 知识库 / 技能 / 工作流（对齐 UI 设计稿）
class KnowledgePage extends StatelessWidget {
  const KnowledgePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('知识库 / 技能 / 工作流'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
        children: const [
          SettingGroup(
            children: [
              SettingRow(label: '知识库', value: '3 条'),
            ],
          ),
          SettingGroup(
            children: [
              SettingRow(label: '技能 Skills', value: '快速选 /'),
              SettingRow(label: '导入 / 导出'),
            ],
          ),
          SettingGroup(
            children: [
              SettingRow(label: '工作流 Workflow', value: '2 条'),
            ],
          ),
        ],
      ),
    );
  }
}
