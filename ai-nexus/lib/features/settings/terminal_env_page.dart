import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/widgets/setting_widgets.dart';

/// 补充配置 · 终端环境（对齐 UI 设计稿，只保留 Ubuntu 24.04）
class TerminalEnvPage extends StatefulWidget {
  const TerminalEnvPage({super.key});

  @override
  State<TerminalEnvPage> createState() => _TerminalEnvPageState();
}

class _TerminalEnvPageState extends State<TerminalEnvPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('终端环境'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
        children: const [
          SettingGroup(
            children: [
              OptionRow(label: 'Ubuntu 24.04', hint: '内置 proot', selected: true),
            ],
          ),
          SettingGroup(
            children: [
              SettingRow(label: 'Python 版本', value: '3.12'),
              SettingRow(label: 'Node 版本', value: '20'),
              SettingRow(label: '默认 Shell', value: 'bash'),
            ],
          ),
          SettingGroup(
            children: [
              SettingRow(label: '导入自定义 rootfs'),
              SettingRow(label: '挂载文件系统'),
              SwitchRow(label: 'SSH 服务', value: false),
            ],
          ),
        ],
      ),
    );
  }
}
