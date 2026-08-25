import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/widgets/setting_widgets.dart';

/// 补充配置 · 搜索 / 多模态 / 语音（对齐 UI 设计稿）
class SearchMultimodalPage extends StatelessWidget {
  const SearchMultimodalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('搜索 / 多模态 / 语音'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
        children: const [
          SettingGroup(
            children: [
              SwitchRow(label: '联网搜索', value: true),
              SettingRow(label: '搜索引擎', value: 'Tavily'),
            ],
          ),
          SettingGroup(
            children: [
              SwitchRow(label: '图片识别', value: true),
              SwitchRow(label: 'PDF 解析', value: true),
            ],
          ),
          SettingGroup(
            children: [
              SwitchRow(label: '语音朗读 TTS', value: false),
              SwitchRow(label: '语音输入 ASR', value: false),
            ],
          ),
        ],
      ),
    );
  }
}
