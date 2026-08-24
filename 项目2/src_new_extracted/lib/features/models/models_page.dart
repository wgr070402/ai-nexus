import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/models/chat_models.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/llm_service.dart';

/// 服务商预设（OpenAI 兼容 endpoints），供编辑时快速填充。
const Map<String, String> _providerBaseUrls = <String, String>{
  'deepseek': 'https://api.deepseek.com/v1',
  'openai': 'https://api.openai.com/v1',
  'moonshot': 'https://api.moonshot.cn/v1',
  'zhipu': 'https://open.bigmodel.cn/api/paas/v4',
  'qwen': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  'openrouter': 'https://openrouter.ai/api/v1',
  'ollama': 'http://localhost:11434/v1',
  'custom': '',
};

/// 模型中心：多服务商模型管理（增删改、设为默认、API Key 安全存储、连接测试）。
class ModelsPage extends StatefulWidget {
  const ModelsPage({super.key});

  @override
  State<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends State<ModelsPage> {
  List<ModelConfig> _models = <ModelConfig>[];
  String _activeId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final models = await AppStorage.loadModels();
    final activeId = await AppStorage.activeModelId();
    if (!mounted) return;
    setState(() {
      _models = models;
      _activeId = activeId ?? (models.isEmpty ? '' : models.first.id);
    });
  }

  Future<void> _openEditor({ModelConfig? model}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ModelEditor(model: model),
    );
    _load();
  }

  Future<void> _setActive(String id) async {
    await AppStorage.setActiveModelId(id);
    dev.log('设为默认模型 id=$id', name: 'ModelCenter');
    _load();
  }

  Future<void> _delete(ModelConfig model) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('删除模型'),
        content: Text('确定删除「${model.name}」及其 API Key 吗？'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await AppStorage.deleteModel(model.id);
      dev.log('删除模型 id=${model.id} name=${model.name}', name: 'ModelCenter');
      _load();
    }
  }

  Future<void> _test(ModelConfig model) async {
    final result = await _probe(model);
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('测试 · ${model.name}'),
        content: Text(result,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭')),
        ],
      ),
    );
  }

  /// 向模型发送一条最小消息，返回成功提示或错误信息。
  Future<String> _probe(ModelConfig model) async {
    try {
      final buffer = StringBuffer();
      await for (final delta in const LlmService().streamChat(
        model: model,
        messages: <ChatMessage>[
          ChatMessage(
              id: 'probe', role: ChatRole.user, content: '回复 OK 两个字符'),
        ],
      )) {
        buffer.write(delta);
        if (buffer.length > 60) break;
      }
      dev.log('测试成功 model=${model.model} 返回=${buffer.toString()}',
          name: 'ModelCenter');
      return '连接成功，返回：${buffer.toString().trim()}';
    } catch (e) {
      dev.log('测试失败 model=${model.model} error=$e',
          name: 'ModelCenter', error: e);
      return '连接失败：$e';
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    final list = _models.map((m) => m.toJson()).toList();
    final json = const JsonEncoder.withIndent('  ').convert(list);
    await Clipboard.setData(ClipboardData(text: json));
    dev.log('导出模型数=${list.length}（不含 API Key）', name: 'ModelCenter');
    _snack('已导出 ${list.length} 个模型配置到剪贴板（不含 Key）');
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('导入模型配置'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 8,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: '粘贴 JSON 数组 …'),
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('导入')),
        ],
      ),
    );
    controller.dispose();
    if (json == null || json.trim().isEmpty) return;
    try {
      final list = (jsonDecode(json) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
      int count = 0;
      for (final item in list) {
        final model = ModelConfig.fromJson(item);
        if (model.id.isEmpty || model.model.isEmpty || model.baseUrl.isEmpty) {
          continue;
        }
        await AppStorage.saveModel(model);
        count++;
      }
      dev.log('导入完成 count=$count total=${list.length}', name: 'ModelCenter');
      _snack('成功导入 $count 个模型');
      _load();
    } catch (e) {
      dev.log('导入失败：$e', name: 'ModelCenter', error: e);
      _snack('导入失败：JSON 格式错误');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模型中心'),
        actions: <Widget>[
          IconButton(
            tooltip: '导出模型配置',
            icon: const Icon(Icons.upload_outlined),
            onPressed: _export,
          ),
          IconButton(
            tooltip: '导入模型配置',
            icon: const Icon(Icons.download_outlined),
            onPressed: _import,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _models.isEmpty
          ? const Center(
              child: Text('暂无模型，点击右下角添加',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _models.length,
              itemBuilder: (BuildContext context, int index) =>
                  _modelCard(_models[index]),
            ),
    );
  }

  Widget _modelCard(ModelConfig model) {
    final isActive = model.id == _activeId;
    final hasKey = model.requiresKey && model.apiKey.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.border,
          width: isActive ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(model.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('默认',
                      style: TextStyle(fontSize: 10, color: AppColors.primaryLight)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${model.provider} · ${model.model}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(model.baseUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(
                hasKey || !model.requiresKey
                    ? Icons.check_circle
                    : Icons.error_outline,
                size: 15,
                color: hasKey || !model.requiresKey
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  !model.requiresKey
                      ? '无需 Key'
                      : (hasKey ? '已配置 Key' : '未配置 Key'),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              if (!isActive)
                TextButton(
                    onPressed: () => _setActive(model.id),
                    child: const Text('设为默认')),
              IconButton(
                tooltip: '测试连接',
                icon: const Icon(Icons.flash_on_outlined,
                    size: 18, color: AppColors.textSecondary),
                onPressed: () => _test(model),
              ),
              IconButton(
                tooltip: '编辑',
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.textSecondary),
                onPressed: () => _openEditor(model: model),
              ),
              IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.danger),
                onPressed: () => _delete(model),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 模型编辑器（新建 / 编辑）。
class _ModelEditor extends StatefulWidget {
  const _ModelEditor({required this.model});
  final ModelConfig? model;

  @override
  State<_ModelEditor> createState() => _ModelEditorState();
}

class _ModelEditorState extends State<_ModelEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.model?.name ?? '');
  late final TextEditingController _baseUrl =
      TextEditingController(text: widget.model?.baseUrl ?? '');
  late final TextEditingController _model =
      TextEditingController(text: widget.model?.model ?? '');
  final TextEditingController _apiKey = TextEditingController();

  late String _provider = widget.model?.provider ?? 'custom';
  late bool _requiresKey = widget.model?.requiresKey ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _show('请填写模型名称');
      return;
    }
    final model = _model.text.trim();
    if (model.isEmpty) {
      _show('请填写模型标识');
      return;
    }
    setState(() => _saving = true);
    final baseUrl = _baseUrl.text.trim();
    final requiresKey = _requiresKey;
    final config = ModelConfig(
      id: widget.model?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      provider: _provider,
      baseUrl: baseUrl,
      model: model,
      apiKey: _apiKey.text.trim(),
      requiresKey: requiresKey,
    );
    dev.log(
      '保存模型 id=${config.id} name=$name provider=$_provider model=$model '
      'requiresKey=$requiresKey keyLen=${_apiKey.text.trim().length}',
      name: 'ModelCenter',
    );
    await AppStorage.saveModel(config);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        isDense: true,
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(widget.model == null ? '新建模型' : '编辑模型',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 14),
              TextField(
                  controller: _name,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: _dec('显示名称')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _provider,
                dropdownColor: AppColors.surfaceLight,
                decoration: _dec('服务商'),
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                items: _providerBaseUrls.keys
                    .map((p) => DropdownMenuItem<String>(
                          value: p,
                          child: Text(p),
                        ))
                    .toList(),
                onChanged: (String? v) {
                  if (v == null) return;
                  setState(() {
                    _provider = v;
                    final preset = _providerBaseUrls[v] ?? '';
                    if (preset.isNotEmpty &&
                        _baseUrl.text.trim().isEmpty) {
                      _baseUrl.text = preset;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _baseUrl,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: _dec('Base URL', hint: 'https://.../v1')),
              const SizedBox(height: 12),
              TextField(
                  controller: _model,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: _dec('模型标识', hint: 'gpt-4o-mini')),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _requiresKey,
                activeTrackColor: AppColors.primary,
                title: const Text('需要 API Key',
                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                contentPadding: EdgeInsets.zero,
                onChanged: (bool v) =>
                    setState(() => _requiresKey = v),
              ),
              if (_requiresKey) ...<Widget>[
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKey,
                  obscureText: true,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: _dec('API Key',
                      hint: widget.model == null ? '' : '留空表示不修改已存 Key'),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '保存中…' : '保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}