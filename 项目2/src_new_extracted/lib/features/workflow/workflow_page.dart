import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app/theme.dart';
import '../../core/models/agent_models.dart';
import '../../core/models/chat_models.dart';
import '../../core/models/workflow_models.dart';
import '../../core/services/agent_controller.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/llm_service.dart';
import '../../core/services/workflow_controller.dart';

/// 工作流板块：多智能体顺序编排、逐步执行、上下文链式传递。
class WorkflowPage extends StatefulWidget {
  const WorkflowPage({super.key});

  @override
  State<WorkflowPage> createState() => _WorkflowPageState();
}

class _WorkflowPageState extends State<WorkflowPage> {
  final WorkflowController _workflow = WorkflowController();
  final AgentController _agent = AgentController();
  List<ModelConfig> _models = <ModelConfig>[];

  @override
  void initState() {
    super.initState();
    _workflow.init();
    _agent.init();
    _loadModels();
  }

  @override
  void dispose() {
    _workflow.dispose();
    _agent.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    final models = await AppStorage.loadModels();
    if (!mounted) return;
    setState(() => _models = models);
  }

  Future<void> _openEditor({Workflow? workflow}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => _WorkflowEditorSheet(
        agents: _agent.agents,
        workflow: workflow,
        onSave: (Workflow w) => _workflow.save(w),
      ),
    );
    setState(() {});
  }

  Future<void> _openRun(Workflow workflow) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkflowRunView(
          workflow: workflow,
          agents: _agent.agents,
          models: _models,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _confirmDelete(Workflow workflow) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('删除工作流'),
        content: Text('确定删除「${workflow.title}」吗？'),
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
    if (ok == true) await _workflow.delete(workflow.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('工作流')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.account_tree_outlined),
      ),
      body: ListenableBuilder(
        listenable: _workflow,
        builder: (BuildContext context, _) {
          if (_workflow.workflows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.account_tree_outlined,
                        size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text('暂无工作流',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 6),
                    Text('点击右下角编排一个多智能体工作流',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _workflow.workflows.length,
            itemBuilder: (BuildContext context, int index) {
              final w = _workflow.workflows[index];
              return _WorkflowCard(
                workflow: w,
                onRun: () => _openRun(w),
                onEdit: () => _openEditor(workflow: w),
                onDelete: () => _confirmDelete(w),
              );
            },
          );
        },
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({
    required this.workflow,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
  });

  final Workflow workflow;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_tree_outlined,
                    size: 22, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(workflow.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    if (workflow.description.isNotEmpty)
                      Text(workflow.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('${workflow.steps.length} 个步骤',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
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
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('删除'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: workflow.steps.isEmpty ? null : onRun,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('运行'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 步骤草稿（编辑器内使用）。
class _StepDraft {
  _StepDraft({String name = '', String prompt = '', this.agentId = ''})
      : nameController = TextEditingController(text: name),
        promptController = TextEditingController(text: prompt);

  final TextEditingController nameController;
  final TextEditingController promptController;
  String agentId;

  void dispose() {
    nameController.dispose();
    promptController.dispose();
  }
}

class _WorkflowEditorSheet extends StatefulWidget {
  const _WorkflowEditorSheet({
    required this.agents,
    required this.workflow,
    required this.onSave,
  });

  final List<Agent> agents;
  final Workflow? workflow;
  final Future<void> Function(Workflow) onSave;

  @override
  State<_WorkflowEditorSheet> createState() => _WorkflowEditorSheetState();
}

class _WorkflowEditorSheetState extends State<_WorkflowEditorSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.workflow?.title ?? '');
  late final TextEditingController _desc =
      TextEditingController(text: widget.workflow?.description ?? '');
  late final List<_StepDraft> _steps;

  @override
  void initState() {
    super.initState();
    _steps = (widget.workflow?.steps ?? <WorkflowStep>[])
        .map((s) => _StepDraft(name: s.name, prompt: s.prompt, agentId: s.agentId))
        .toList();
    if (_steps.isEmpty) _steps.add(_StepDraft());
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写工作流名称')),
      );
      return;
    }
    final steps = _steps
        .where((s) => s.nameController.text.trim().isNotEmpty)
        .map(
          (s) => WorkflowStep(
            id: DateTime.now().microsecondsSinceEpoch.toString() +
                s.nameController.text,
            name: s.nameController.text.trim(),
            prompt: s.promptController.text.trim(),
            agentId: s.agentId,
          ),
        )
        .toList();
    final workflow = Workflow(
      id: widget.workflow?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      description: _desc.text.trim(),
      steps: steps,
    );
    await widget.onSave(workflow);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(widget.workflow == null ? '新建工作流' : '编辑工作流',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            _field(_title, '名称'),
            const SizedBox(height: 12),
            _field(_desc, '描述'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text('步骤（按顺序执行）',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                TextButton.icon(
                  onPressed: () => setState(() => _steps.add(_StepDraft())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加步骤'),
                ),
              ],
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _steps.length,
                itemBuilder: (BuildContext context, int index) {
                  return _stepItem(index);
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('保存')),
          ],
        ),
      ),
    );
  }

  Widget _stepItem(int index) {
    final draft = _steps[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Text('${index + 1}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLight)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.nameController,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                  decoration: _inputDecoration('步骤名（如 需求分析）'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    size: 18, color: AppColors.danger),
                onPressed: () => setState(() {
                  draft.dispose();
                  _steps.removeAt(index);
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: draft.promptController,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: _inputDecoration('指令（该步做什么）'),
          ),
          const SizedBox(height: 8),
          _agentDropdown(draft),
        ],
      ),
    );
  }

  Widget _agentDropdown(_StepDraft draft) {
    return DropdownButtonFormField<String>(
      initialValue: draft.agentId,
      dropdownColor: AppColors.surfaceLight,
      decoration: _inputDecoration('指派 Agent（空 = 默认模型）'),
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      items: <DropdownMenuItem<String>>[
        const DropdownMenuItem<String>(value: '', child: Text('默认模型')),
        ...widget.agents.map((a) => DropdownMenuItem<String>(
              value: a.id,
              child: Text(a.name),
            )),
      ],
      onChanged: (String? v) => setState(() => draft.agentId = v ?? ''),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
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

/// 工作流运行视图：逐步顺序执行，实时流式展示每步输出。
class WorkflowRunView extends StatefulWidget {
  const WorkflowRunView({
    super.key,
    required this.workflow,
    required this.agents,
    required this.models,
  });

  final Workflow workflow;
  final List<Agent> agents;
  final List<ModelConfig> models;

  @override
  State<WorkflowRunView> createState() => _WorkflowRunViewState();
}

class _WorkflowRunViewState extends State<WorkflowRunView> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final Map<String, String> _outputs = <String, String>{};
  String? _currentStepId;
  bool _running = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Agent? _agentById(String id) {
    for (final a in widget.agents) {
      if (a.id == id) return a;
    }
    return null;
  }

  ModelConfig? _modelById(String id) {
    for (final m in widget.models) {
      if (m.id == id) return m;
    }
    return null;
  }

  ModelConfig? _resolveModel(WorkflowStep step) {
    if (step.agentId.isNotEmpty) {
      final agent = _agentById(step.agentId);
      if (agent != null && agent.modelId.isNotEmpty) {
        return _modelById(agent.modelId);
      }
    }
    return widget.models.isEmpty ? null : widget.models.first;
  }

  Future<void> _run() async {
    final input = _input.text.trim();
    if (input.isEmpty || _running) return;
    final steps = widget.workflow.steps
        .where((s) => s.name.trim().isNotEmpty)
        .toList();
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该工作流没有可用步骤')),
      );
      return;
    }

    setState(() {
      _running = true;
      _outputs.clear();
    });

    String ctx = input;
    for (final step in steps) {
      setState(() => _currentStepId = step.id);
      final output = await _runStep(step, ctx);
      _outputs[step.id] = output;
      if (output.isNotEmpty) {
        ctx += '\n\n【步骤：${step.name}】\n$output';
      }
    }

    setState(() {
      _running = false;
      _currentStepId = null;
    });
    _scrollToBottom();
  }

  Future<String> _runStep(WorkflowStep step, String context) async {
    final model = _resolveModel(step);
    if (model == null) {
      return '[未找到可用模型，请先在设置中配置模型]';
    }
    final agent = step.agentId.isNotEmpty ? _agentById(step.agentId) : null;
    final systemPrompt =
        agent != null && agent.systemPrompt.trim().isNotEmpty
            ? agent.systemPrompt
            : '你是一个协作工作流中的执行单元，请按指令完成当前步骤并给出清晰结果。';

    final messages = <ChatMessage>[
      ChatMessage(id: 'sys-${step.id}', role: ChatRole.system, content: systemPrompt),
      ChatMessage(
        id: 'usr-${step.id}',
        role: ChatRole.user,
        content: '${step.prompt}\n\n--- 上下文（含初始任务与前面步骤输出） ---\n$context',
      ),
    ];

    final buffer = StringBuffer();
    try {
      await for (final delta in const LlmService().streamChat(
        model: model,
        messages: messages,
      )) {
        buffer.write(delta);
        _outputs[step.id] = buffer.toString();
        if (mounted) setState(() {});
        _scrollToBottom();
      }
      return buffer.toString();
    } catch (e) {
      return '[执行失败：$e]';
    }
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.workflow.steps
        .where((s) => s.name.trim().isNotEmpty)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.workflow.title)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _input,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                labelText: '初始任务 / 输入',
                labelStyle: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _running ? null : _run,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(_running ? '执行中…' : '开始执行'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: steps.length,
              itemBuilder: (BuildContext context, int index) {
                final step = steps[index];
                return _StepResultCard(
                  step: step,
                  output: _outputs[step.id] ?? '',
                  status: _statusOf(step),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  _StepStatus _statusOf(WorkflowStep step) {
    if (_currentStepId == step.id) return _StepStatus.running;
    if (_outputs.containsKey(step.id)) {
      final out = _outputs[step.id] ?? '';
      if (out.startsWith('[执行失败')) return _StepStatus.error;
      return _StepStatus.done;
    }
    return _StepStatus.pending;
  }
}

enum _StepStatus { pending, running, done, error }

class _StepResultCard extends StatelessWidget {
  const _StepResultCard({
    required this.step,
    required this.output,
    required this.status,
  });

  final WorkflowStep step;
  final String output;
  final _StepStatus status;

  @override
  Widget build(BuildContext context) {
    final Color dotColor = switch (status) {
      _StepStatus.running => AppColors.primaryLight,
      _StepStatus.done => AppColors.success,
      _StepStatus.error => AppColors.danger,
      _StepStatus.pending => AppColors.textMuted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == _StepStatus.running
              ? AppColors.primary
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(step.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              if (status == _StepStatus.running)
                const Text('执行中…',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.primaryLight)),
            ],
          ),
          if (output.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            if (status == _StepStatus.running)
              MarkdownBody(
                data: '$output▌',
                selectable: true,
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textPrimary),
                  code: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.accent,
                      backgroundColor: AppColors.background),
                ),
              )
            else
              MarkdownBody(
                data: output,
                selectable: true,
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textPrimary),
                  code: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.accent,
                      backgroundColor: AppColors.background),
                ),
              ),
          ],
        ],
      ),
    );
  }
}