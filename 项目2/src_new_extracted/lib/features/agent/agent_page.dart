import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/models/agent_models.dart';
import '../../core/models/agent_templates.dart';
import '../../core/models/chat_models.dart';
import '../../core/services/agent_controller.dart';
import '../../core/services/app_storage.dart';

/// Agent 板块：自定义智能体的增删改查 + 基础权限配置。
class AgentPage extends StatefulWidget {
  const AgentPage({super.key});

  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage> {
  final AgentController _agent = AgentController();
  List<ModelConfig> _models = <ModelConfig>[];

  @override
  void initState() {
    super.initState();
    _agent.init();
    _loadModels();
  }

  @override
  void dispose() {
    _agent.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    final models = await AppStorage.loadModels();
    if (!mounted) return;
    setState(() => _models = models);
  }

  Future<void> _openEditor({Agent? agent, AgentTemplate? template}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => _AgentEditorSheet(
        controller: _agent,
        agent: agent,
        template: template,
        models: _models,
      ),
    );
    setState(() {});
  }

  /// 新建入口：空白 / 从模板库创建。
  Future<void> _openCreateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => _CreateAgentSheet(
        onBlank: () {
          Navigator.of(context).pop();
          _openEditor();
        },
        onTemplate: (AgentTemplate t) {
          Navigator.of(context).pop();
          _openEditor(template: t);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent'),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: _onMenuAction,
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'import',
                child: Text('导入 Agent (JSON)'),
              ),
              PopupMenuItem<String>(
                value: 'exportAll',
                child: Text('导出全部 Agent'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: _agent,
        builder: (BuildContext context, _) {
          if (_agent.agents.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.smart_toy_outlined,
                        size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text('暂无 Agent',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 6),
                    Text('点击右下角 + 新建一个自定义智能体',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _agent.agents.length,
            itemBuilder: (BuildContext context, int index) {
              final agent = _agent.agents[index];
              return _AgentCard(
                agent: agent,
                modelName: _modelName(agent.modelId),
                onEdit: () => _openEditor(agent: agent),
                onExport: () => _exportAgent(agent),
                onDelete: () => _confirmDelete(agent),
                onToggle: () => _agent.toggleEnabled(agent.id),
              );
            },
          );
        },
      ),
    );
  }

  String _modelName(String modelId) {
    for (final m in _models) {
      if (m.id == modelId) return m.name;
    }
    return modelId.isEmpty ? '未指定模型' : modelId;
  }

  Future<void> _confirmDelete(Agent agent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('删除 Agent'),
        content: Text('确定删除「${agent.name}」吗？此操作不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _agent.deleteAgent(agent.id);
    }
  }

  // ---------- 导入 / 导出 ----------

  void _onMenuAction(String action) {
    dev.log('菜单动作 action=$action 当前 Agent 数=${_agent.agents.length}',
        name: 'AgentImportExport');
    if (action == 'import') {
      _importAgent();
    } else if (action == 'exportAll') {
      _exportAll();
    }
  }

  Future<void> _exportAgent(Agent agent) async {
    final json = jsonEncode(agent.toJson());
    dev.log(
      '导出单个 Agent id=${agent.id} name=${agent.name} memory=${agent.memory.length} '
      'size=${json.length}B',
      name: 'AgentImportExport',
    );
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) _showJsonDialog('导出 Agent：${agent.name}', json);
  }

  Future<void> _exportAll() async {
    final list = _agent.agents.map((a) => a.toJson()).toList();
    final json = jsonEncode(list);
    dev.log(
      '导出全部 Agent 数量=${list.length} size=${json.length}B',
      name: 'AgentImportExport',
    );
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) _showJsonDialog('导出全部 Agent', json);
  }

  Future<void> _importAgent() async {
    final text = await _promptImport();
    if (text == null || text.trim().isEmpty) return;
    dev.log('导入原始数据 length=${text.trim().length}', name: 'AgentImportExport');
    try {
      final decoded = jsonDecode(text.trim());
      final items = decoded is List ? decoded : <dynamic>[decoded];
      int added = 0;
      for (final item in items) {
        if (item is! Map) {
          dev.log('跳过非法条目 类型=${item.runtimeType}', name: 'AgentImportExport');
          continue;
        }
        final agent = Agent.fromJson(Map<String, dynamic>.from(item));
        await _agent.addAgent(agent);
        added++;
        dev.log(
          '导入成功 Agent id=${agent.id} name=${agent.name} '
          'memory=${agent.memory.length} permissions=${agent.permissions.length}',
          name: 'AgentImportExport',
        );
      }
      dev.log('导入完成 新增=$added', name: 'AgentImportExport');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 $added 个 Agent')),
        );
      }
    } catch (e, st) {
      dev.log('导入失败：$e', name: 'AgentImportExport', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入失败：JSON 解析错误')),
        );
      }
    }
  }

  Future<String?> _promptImport() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('导入 Agent (JSON)'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 8,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              hintText: '粘贴 JSON（单个对象或数组）',
              hintStyle:
                  const TextStyle(fontSize: 12, color: AppColors.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  void _showJsonDialog(String title, String json) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('复制'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// Agent 列表卡片。
class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.modelName,
    required this.onEdit,
    required this.onExport,
    required this.onDelete,
    required this.onToggle,
  });

  final Agent agent;
  final String modelName;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final riskyCount = agent.permissions.entries
        .where((e) =>
            e.value == PermissionPolicy.alwaysAllow &&
            PermissionGuard.isRisky(e.key))
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.smart_toy_outlined,
                    size: 22, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(agent.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    Text(
                      agent.role.isEmpty ? '未设置身份' : agent.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: agent.enabled,
                activeTrackColor: AppColors.primary,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _Tag(text: modelName),
              const SizedBox(width: 6),
              _Tag(text: '技能 ${agent.skills.length}'),
              const SizedBox(width: 6),
              _Tag(text: '工具 ${agent.tools.length}'),
              const SizedBox(width: 6),
              _Tag(text: '记忆 ${agent.memory.length}'),
            ],
          ),
          if (riskyCount > 0) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const Icon(Icons.warning_amber_rounded,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
                Text('$riskyCount 项高危权限已设为「始终允许」',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.warning)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('编辑'),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.ios_share, size: 16),
                label: const Text('导出'),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('删除'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    );
  }
}

/// 新建 Agent 底部弹窗：选择「空白新建」或「从模板库创建」。
class _CreateAgentSheet extends StatelessWidget {
  const _CreateAgentSheet({
    required this.onBlank,
    required this.onTemplate,
  });

  final VoidCallback onBlank;
  final void Function(AgentTemplate template) onTemplate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('新建 Agent',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: AppColors.primaryLight),
              ),
              title: const Text('空白新建',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              subtitle: const Text('从头自定义身份、提示词与权限',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              onTap: onBlank,
            ),
            const SizedBox(height: 8),
            const Text('从模板创建',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: AgentTemplateRegistry.templates.length,
                itemBuilder: (BuildContext context, int index) {
                  final t = AgentTemplateRegistry.templates[index];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(t.icon, color: AppColors.primaryLight, size: 20),
                    ),
                    title: Text(t.name,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary)),
                    subtitle: Text(t.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    trailing:
                        const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () => onTemplate(t),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Agent 新建/编辑底部弹窗（含权限配置）。
class _AgentEditorSheet extends StatefulWidget {
  const _AgentEditorSheet({
    required this.controller,
    required this.agent,
    required this.template,
    required this.models,
  });

  final AgentController controller;
  final Agent? agent;
  final AgentTemplate? template;
  final List<ModelConfig> models;

  @override
  State<_AgentEditorSheet> createState() => _AgentEditorSheetState();
}

class _AgentEditorSheetState extends State<_AgentEditorSheet> {
  late final TextEditingController _name = TextEditingController(
      text: widget.agent?.name ?? widget.template?.name ?? '');
  late final TextEditingController _role = TextEditingController(
      text: widget.agent?.role ?? widget.template?.role ?? '');
  late final TextEditingController _systemPrompt = TextEditingController(
      text: widget.agent?.systemPrompt ?? widget.template?.systemPrompt ?? '');
  late final TextEditingController _skills = TextEditingController(
      text: (widget.agent?.skills ?? widget.template?.skills ?? <String>[])
          .join(', '));
  late final TextEditingController _tools = TextEditingController(
      text: (widget.agent?.tools ?? widget.template?.tools ?? <String>[])
          .join(', '));
  late final TextEditingController _memory = TextEditingController(
      text: widget.agent?.memory.entries
              .map((e) => '${e.key}: ${e.value}')
              .join('\n') ??
          '');

  late String _modelId = widget.agent?.modelId ?? '';
  late final Map<AgentPermission, PermissionPolicy> _permissions =
      Map<AgentPermission, PermissionPolicy>.from(
          widget.agent?.permissions ?? PermissionGuard.defaultPermissions());

  bool get _isEdit => widget.agent != null;

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _systemPrompt.dispose();
    _skills.dispose();
    _tools.dispose();
    _memory.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写 Agent 名称')));
      return;
    }
    final agent = Agent(
      id: widget.agent?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      role: _role.text.trim(),
      systemPrompt: _systemPrompt.text.trim(),
      modelId: _modelId,
      skills: _splitList(_skills.text),
      tools: _splitList(_tools.text),
      memory: _parseMemory(_memory.text),
      permissions: _permissions,
      enabled: widget.agent?.enabled ?? true,
      createdAt: widget.agent?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await widget.controller.updateAgent(agent);
    if (mounted) Navigator.of(context).pop();
  }

  static List<String> _splitList(String text) => text
      .split(RegExp(r'[,，]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// 解析「key: value」多行记忆输入为 Map。
  static Map<String, String> _parseMemory(String text) {
    final map = <String, String>{};
    for (final line in text.split('\n')) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final k = line.substring(0, idx).trim();
      final v = line.substring(idx + 1).trim();
      if (k.isNotEmpty) map[k] = v;
    }
    dev.log('解析记忆输入 条目数=${map.length} keys=[${map.keys.join(', ')}]',
        name: 'AgentMemory');
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(_isEdit ? '编辑 Agent' : '新建 Agent',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 14),
              _field(_name, '名称'),
              const SizedBox(height: 12),
              _field(_role, '身份 / 角色描述'),
              const SizedBox(height: 12),
              _field(_systemPrompt, '系统提示词', maxLines: 3),
              const SizedBox(height: 12),
              _modelDropdown(),
              const SizedBox(height: 12),
              _field(_skills, '技能 Skills（逗号分隔）'),
              const SizedBox(height: 12),
              _field(_tools, '工具 Tools（逗号分隔）'),
              const SizedBox(height: 12),
              _field(_memory, '记忆（每行「键: 值」，如 style: 简洁专业）', maxLines: 3),
              const SizedBox(height: 16),
              const Text('权限策略',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('高危操作默认需确认或拒绝；默认禁用敏感目录与系统设置访问',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              ...AgentPermission.values.map(_permissionRow),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionRow(AgentPermission permission) {
    final policy = _permissions[permission] ?? PermissionPolicy.ask;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          if (PermissionGuard.isRisky(permission))
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.warning_amber_rounded,
                  size: 14, color: AppColors.warning),
            ),
          Expanded(
            child: Text('${permission.label}'
                '${PermissionGuard.isRisky(permission) ? '（高危）' : ''}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
          _policyDropdown(permission, policy),
        ],
      ),
    );
  }

  Widget _policyDropdown(AgentPermission permission, PermissionPolicy policy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PermissionPolicy>(
          value: policy,
          dropdownColor: AppColors.surfaceLight,
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          items: PermissionPolicy.values
              .map((p) => DropdownMenuItem<PermissionPolicy>(
                    value: p,
                    child: Text(p.label),
                  ))
              .toList(),
          onChanged: (PermissionPolicy? v) {
            if (v != null) {
              setState(() => _permissions[permission] = v);
            }
          },
        ),
      ),
    );
  }

  Widget _modelDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _modelId,
      dropdownColor: AppColors.surfaceLight,
      decoration: _inputDecoration('关联模型'),
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      items: <DropdownMenuItem<String>>[
        const DropdownMenuItem<String>(value: '', child: Text('未指定')),
        ...widget.models.map((m) => DropdownMenuItem<String>(
              value: m.id,
              child: Text('${m.name}（${m.model}）'),
            )),
      ],
      onChanged: (String? v) => setState(() => _modelId = v ?? ''),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}