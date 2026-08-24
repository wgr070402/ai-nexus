import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app/theme.dart';
import '../../core/models/chat_models.dart';
import '../../core/models/generator_models.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/file_service.dart';
import '../../core/services/llm_service.dart';

/// AI 生成器中心：统一覆盖 Demo 原型 / 脚手架 / 注释翻译 / 单元测试 /
/// 文字游戏 / 网页小游戏 / 游戏设定 / 文档处理 / 批量脚本 / 数据模拟 / Mermaid 流程图。
///
/// 选定模板 + 输入需求 → 流式生成 → 结果可复制或保存到工作区（代码可去终端运行）。
class GeneratorPage extends StatefulWidget {
  const GeneratorPage({super.key});

  @override
  State<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  List<ModelConfig> _models = <ModelConfig>[];
  String _activeModelId = '';
  GeneratorTemplate _template = GeneratorTemplateRegistry.templates.first;
  final TextEditingController _input = TextEditingController();

  bool _busy = false;
  String _output = '';

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    final models = await AppStorage.loadModels();
    final activeId = await AppStorage.activeModelId();
    if (!mounted) return;
    setState(() {
      _models = models;
      _activeModelId = (activeId != null && models.any((m) => m.id == activeId))
          ? activeId
          : (models.isEmpty ? '' : models.first.id);
    });
  }

  ModelConfig? get _activeModel {
    for (final m in _models) {
      if (m.id == _activeModelId) return m;
    }
    return _models.isEmpty ? null : _models.first;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _generate() async {
    final requirement = _input.text.trim();
    if (requirement.isEmpty || _busy) return;
    final model = _activeModel;
    if (model == null) {
      _snack('请先在模型中心配置一个模型');
      return;
    }
    setState(() {
      _busy = true;
      _output = '';
    });

    final buffer = StringBuffer();
    try {
      await for (final delta in const LlmService().streamChat(
        model: model,
        messages: <ChatMessage>[
          ChatMessage(
            id: 'gen-sys',
            role: ChatRole.system,
            content: _template.systemPrompt,
          ),
          ChatMessage(
            id: 'gen-user',
            role: ChatRole.user,
            content: requirement,
          ),
        ],
      )) {
        buffer.write(delta);
        if (mounted) setState(() => _output = buffer.toString());
      }
    } catch (e) {
      dev.log('生成失败：$e', name: 'Generator', error: e);
      if (mounted) {
        setState(() => _output = buffer.isEmpty ? '生成失败：$e' : '$buffer\n\n[中断：$e]');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    if (_output.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _output));
    _snack('已复制到剪贴板');
  }

  Future<void> _save() async {
    if (_output.isEmpty) return;
    try {
      final file = await FileService.saveText(_template.defaultFileName, _output);
      dev.log('保存到工作区 name=${file.name}', name: 'Generator');
      _snack('已保存到工作区：${file.name}（可在文件中心/终端查看运行）');
    } catch (e) {
      dev.log('保存失败：$e', name: 'Generator', error: e);
      _snack('保存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 生成器'),
        actions: <Widget>[
          if (_output.isNotEmpty) ...<Widget>[
            IconButton(
              tooltip: '复制',
              onPressed: _copy,
              icon: const Icon(Icons.copy_outlined),
            ),
            IconButton(
              tooltip: '保存到工作区',
              onPressed: _save,
              icon: const Icon(Icons.save_alt_outlined),
            ),
          ],
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildModelBar(),
          _buildTemplateBar(),
          _buildInput(),
          Expanded(child: _buildOutput()),
        ],
      ),
    );
  }

  Widget _buildModelBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: <Widget>[
          const Icon(Icons.smart_toy_outlined,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _models.any((m) => m.id == _activeModelId)
                    ? _activeModelId
                    : (_models.isEmpty ? null : _models.first.id),
                isExpanded: true,
                dropdownColor: AppColors.surfaceLight,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                hint: const Text('选择模型'),
                items: _models
                    .map((m) => DropdownMenuItem<String>(
                          value: m.id,
                          child: Text('${m.name} · ${m.model}',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (String? v) {
                  if (v != null) setState(() => _activeModelId = v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateBar() {
    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: GeneratorTemplateRegistry.templates.length,
        itemBuilder: (BuildContext context, int index) {
          final t = GeneratorTemplateRegistry.templates[index];
          final selected = t.id == _template.id;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _template = t),
              child: Container(
                width: 96,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: selected ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(t.icon,
                        size: 22,
                        color: selected
                            ? AppColors.primaryLight
                            : AppColors.textSecondary),
                    const SizedBox(height: 4),
                    Text(t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected
                                ? AppColors.primaryLight
                                : AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_template.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _input,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  cursorColor: AppColors.primaryLight,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '输入需求，例如「写一个猜数字小游戏」…',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: '生成',
                onPressed: _busy ? null : _generate,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutput() {
    if (_output.isEmpty && !_busy) {
      return const Center(
        child: Text('选择模板并输入需求，点击生成按钮开始',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      );
    }
    if (_output.isEmpty && _busy) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text('正在生成…',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    final data = _busy ? '$_output▌' : _output;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: MarkdownBody(
          data: data,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: const TextStyle(
                fontSize: 14, height: 1.55, color: AppColors.textPrimary),
            code: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.accent,
                backgroundColor: AppColors.background),
            codeblockDecoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
      ),
    );
  }
}
