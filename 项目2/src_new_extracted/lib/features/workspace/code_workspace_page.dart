import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app/theme.dart';
import '../../core/models/chat_models.dart';
import '../../core/models/file_models.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/file_service.dart';
import '../../core/services/llm_service.dart';

/// 多文件代码工作区：多 tab 打开/编辑/保存工作区内的源码文件，
/// 并支持 AI 对当前文件进行批量读写/重构。
class CodeWorkspacePage extends StatefulWidget {
  const CodeWorkspacePage({super.key});

  @override
  State<CodeWorkspacePage> createState() => _CodeWorkspacePageState();
}

/// 一个已打开的编辑 tab。
class _OpenFile {
  _OpenFile(this.file, this.controller);

  final AppFile file;
  final TextEditingController controller;
  bool dirty = false;
}

class _CodeWorkspacePageState extends State<CodeWorkspacePage> {
  List<AppFile> _files = <AppFile>[];
  final List<_OpenFile> _opened = <_OpenFile>[];
  int _activeIndex = -1;

  List<ModelConfig> _models = <ModelConfig>[];
  String _activeModelId = '';

  // AI 辅助
  final TextEditingController _aiInput = TextEditingController();
  String _aiOutput = '';
  bool _aiBusy = false;
  bool _showAi = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadModels();
  }

  @override
  void dispose() {
    for (final o in _opened) {
      o.controller.dispose();
    }
    _aiInput.dispose();
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

  /// 可编辑的文件：源码 + 文本类型。
  Future<void> _refresh() async {
    final all = await FileService.list();
    final editable =
        all.where((f) => f.type == AppFileType.code || f.type == AppFileType.text).toList();
    if (!mounted) return;
    setState(() => _files = editable);
  }

  Future<void> _open(AppFile file) async {
    // 已在打开列表则切到对应 tab
    final existing = _opened.indexWhere((o) => o.file.path == file.path);
    if (existing >= 0) {
      setState(() => _activeIndex = existing);
      return;
    }
    final content = await FileService.readText(file);
    final controller = TextEditingController(text: content);
    setState(() {
      _opened.add(_OpenFile(file, controller));
      _activeIndex = _opened.length - 1;
    });
  }

  void _closeTab(int index) {
    final tab = _opened[index];
    tab.controller.dispose();
    setState(() {
      _opened.removeAt(index);
      if (_activeIndex >= _opened.length) {
        _activeIndex = _opened.isEmpty ? -1 : _opened.length - 1;
      } else if (_activeIndex > index) {
        _activeIndex -= 1;
      }
    });
  }

  Future<void> _saveCurrent() async {
    if (_activeIndex < 0) return;
    final tab = _opened[_activeIndex];
    try {
      await File(tab.file.path).writeAsString(tab.controller.text, flush: true);
      dev.log('保存文件 name=${tab.file.name}', name: 'CodeWorkspace');
      setState(() => tab.dirty = false);
      _snack('已保存：${tab.file.name}');
    } catch (e) {
      dev.log('保存失败：$e', name: 'CodeWorkspace', error: e);
      _snack('保存失败：$e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- AI 辅助 ----------

  Future<void> _aiRun() async {
    final instruction = _aiInput.text.trim();
    if (instruction.isEmpty || _aiBusy) return;
    final model = _activeModel;
    if (model == null) {
      _snack('请先在模型中心配置模型');
      return;
    }
    final current = _activeIndex >= 0 ? _opened[_activeIndex] : null;
    final userContent = current == null
        ? instruction
        : '【当前文件：${current.file.name}】\n'
            '```\n${current.controller.text}\n```\n\n'
            '【指令】$instruction\n\n'
            '请给出处理后的完整代码/内容，不要额外解释。';

    setState(() {
      _aiBusy = true;
      _aiOutput = '';
    });
    final buffer = StringBuffer();
    try {
      await for (final delta in const LlmService().streamChat(
        model: model,
        messages: <ChatMessage>[
          ChatMessage(
            id: 'ws-sys',
            role: ChatRole.system,
            content: '你是代码工作区助手，负责读取、改写、重构用户提供的源码。'
                '只输出处理后的完整代码/内容，不要多余解释。',
          ),
          ChatMessage(id: 'ws-user', role: ChatRole.user, content: userContent),
        ],
      )) {
        buffer.write(delta);
        if (mounted) setState(() => _aiOutput = buffer.toString());
      }
    } catch (e) {
      dev.log('AI 处理失败：$e', name: 'CodeWorkspace', error: e);
      if (mounted) {
        setState(() => _aiOutput = buffer.isEmpty ? '处理失败：$e' : '$buffer\n\n[中断：$e]');
      }
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _aiApply() async {
    if (_aiOutput.isEmpty || _activeIndex < 0) return;
    final tab = _opened[_activeIndex];
    tab.controller.text = _aiOutput;
    setState(() {
      tab.dirty = true;
      _aiOutput = '';
    });
    _snack('已应用到当前文件（记得保存）');
  }

  Future<void> _aiSaveAs() async {
    if (_aiOutput.isEmpty) return;
    final base = _activeIndex >= 0
        ? 'ai_${_opened[_activeIndex].file.name}'
        : 'ai_output.txt';
    try {
      final f = await FileService.saveText(base, _aiOutput);
      _snack('已另存为：${f.name}');
    } catch (e) {
      _snack('另存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('代码工作区'),
        actions: <Widget>[
          IconButton(
            tooltip: '打开文件',
            onPressed: _openFilePicker,
            icon: const Icon(Icons.folder_open_outlined),
          ),
          IconButton(
            tooltip: _showAi ? '收起 AI 面板' : 'AI 辅助',
            onPressed: () => setState(() => _showAi = !_showAi),
            icon: Icon(_showAi ? Icons.smart_toy : Icons.smart_toy_outlined),
          ),
          if (_activeIndex >= 0)
            IconButton(
              tooltip: '保存当前文件',
              onPressed: _saveCurrent,
              icon: const Icon(Icons.save_outlined),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_opened.isNotEmpty) _buildTabBar(),
          Expanded(
            child: _activeIndex < 0 ? _buildEmpty() : _buildEditor(),
          ),
          if (_showAi) _buildAiPanel(),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: _opened.length,
        itemBuilder: (BuildContext context, int index) {
          final tab = _opened[index];
          final active = index == _activeIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _activeIndex = index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: active ? AppColors.primary : AppColors.border),
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      tab.dirty ? '● ${tab.file.name}' : tab.file.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: active ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _closeTab(index),
                      child: Icon(Icons.close,
                          size: 14,
                          color: active ? Colors.white70 : AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.code_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('未打开文件',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('点击右上角打开工作区内的源码 / 文本文件',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openFilePicker,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('打开文件'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    final tab = _opened[_activeIndex];
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: AppColors.surfaceLight,
          child: Text('${tab.file.name}${tab.dirty ? '（未保存）' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: TextField(
            controller: tab.controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: AppColors.textPrimary),
            cursorColor: AppColors.primaryLight,
            onChanged: (_) {
              if (!tab.dirty) setState(() => tab.dirty = true);
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _aiInput,
                  maxLines: 2,
                  minLines: 1,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  cursorColor: AppColors.primaryLight,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '对当前文件下达指令，如「给这段代码加注释」「重构为更清晰的结构」…',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: '执行',
                onPressed: _aiBusy ? null : _aiRun,
                icon: _aiBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_upward, size: 18),
              ),
            ],
          ),
          if (_aiOutput.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: _activeIndex < 0 ? null : _aiApply,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('应用到当前文件'),
                ),
                TextButton.icon(
                  onPressed: _aiSaveAs,
                  icon: const Icon(Icons.save_alt_outlined, size: 16),
                  label: const Text('另存新文件'),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: _aiOutput,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                    p: const TextStyle(
                        fontSize: 13, height: 1.5, color: AppColors.textPrimary),
                    code: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.accent,
                        backgroundColor: AppColors.background),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openFilePicker() async {
    await _refresh();
    if (!mounted) return;
    if (_files.isEmpty) {
      _snack('工作区内暂无源码/文本文件，请先在文件中心上传');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('打开文件',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _files.length,
                itemBuilder: (BuildContext context, int index) {
                  final f = _files[index];
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined,
                        color: AppColors.primaryLight),
                    title: Text(f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary)),
                    subtitle: Text(_sizeLabel(f.size),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                    onTap: () {
                      Navigator.of(context).pop();
                      _open(f);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sizeLabel(int size) {
    if (size >= 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '$size B';
  }
}
