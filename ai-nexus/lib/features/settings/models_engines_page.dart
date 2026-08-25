import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/widgets/setting_widgets.dart';

/// 补充配置 · 模型与引擎（对齐 UI 设计稿）
class ModelsEnginesPage extends StatefulWidget {
  const ModelsEnginesPage({super.key});

  @override
  State<ModelsEnginesPage> createState() => _ModelsEnginesPageState();
}

class _ModelsEnginesPageState extends State<ModelsEnginesPage> {
  int _selected = 0; // 0 本地/云端 · 1 Harness · 2 Codex · 3 Codex++

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('模型与引擎'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
        children: [
          SettingGroup(
            children: [
              OptionRow(
                label: '本地 / 云端模型',
                selected: _selected == 0,
                onTap: () => setState(() => _selected = 0),
              ),
              OptionRow(
                label: 'DeepSeek Harness',
                selected: _selected == 1,
                onTap: () => setState(() => _selected = 1),
              ),
              OptionRow(
                label: 'Codex',
                hint: 'OpenAI CLI',
                selected: _selected == 2,
                onTap: () => setState(() => _selected = 2),
              ),
              OptionRow(
                label: 'Codex++',
                hint: '增强启动器',
                selected: _selected == 3,
                onTap: () => setState(() => _selected = 3),
              ),
            ],
          ),
          const SettingGroup(
            children: [
              SettingRow(label: '供应商', value: 'DeepSeek'),
              SettingRow(label: 'API Key', value: '已配置'),
              SettingRow(label: 'Base URL', value: 'api.deepseek.com/v1', trailing: SizedBox.shrink()),
              SettingRow(label: '模型名', value: 'deepseek-chat', trailing: SizedBox.shrink()),
              SettingRow(label: '测试连接'),
            ],
          ),
          const SettingGroup(
            children: [
              SettingRow(label: 'DeepSeek Harness 服务地址', value: '127.0.0.1:3080', trailing: SizedBox.shrink()),
              SettingRow(label: 'Codex 启动命令', value: 'codex', trailing: SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }
}
