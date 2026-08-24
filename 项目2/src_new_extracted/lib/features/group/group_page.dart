import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app/theme.dart';
import '../../core/models/agent_models.dart';
import '../../core/models/chat_models.dart';
import '../../core/models/group_models.dart';
import '../../core/services/agent_controller.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/group_controller.dart';
import '../../core/services/llm_service.dart';

/// 群聊板块：多智能体协同会话。
///
/// 列表页展示群会话，可新建群聊并勾选参与 Agent；进入会话后，用户发送一条
/// 消息，所有参与 Agent 依据各自身份/系统提示词/模型并行流式回复，
/// 实现多专家角色调度与分步执行。
class GroupPage extends StatefulWidget {
  const GroupPage({super.key});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  final GroupController _group = GroupController();
  final AgentController _agent = AgentController();
  List<ModelConfig> _models = <ModelConfig>[];

  @override
  void initState() {
    super.initState();
    _group.init();
    _agent.init();
    _loadModels();
  }

  @override
  void dispose() {
    _group.dispose();
    _agent.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    final models = await AppStorage.loadModels();
    if (!mounted) return;
    setState(() => _models = models);
  }

  Future<void> _openCreateGroup() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => _CreateGroupSheet(
        agents: _agent.agents.where((a) => a.enabled).toList(),
        onCreate: (String title, List<String> agentIds) async {
          await _group.createGroup(title, agentIds);
        },
      ),
    );
    setState(() {});
  }

  Future<void> _openGroup(GroupSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupChatView(
          session: session,
          controller: _group,
          agents: _agent.agents,
          models: _models,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _confirmDelete(GroupSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('删除群聊'),
        content: Text('确定删除「${session.title}」吗？'),
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
    if (ok == true) await _group.deleteGroup(session.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('群聊')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateGroup,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.group_add_outlined),
      ),
      body: ListenableBuilder(
        listenable: _group,
        builder: (BuildContext context, _) {
          if (_group.sessions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.groups_outlined,
                        size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text('暂无群聊',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 6),
                    Text('点击右下角新建多智能体群聊',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _group.sessions.length,
            itemBuilder: (BuildContext context, int index) {
              final session = _group.sessions[index];
              return _GroupCard(
                session: session,
                onTap: () => _openGroup(session),
                onDelete: () => _confirmDelete(session),
              );
            },
          );
        },
      ),
    );
  }
}

/// 群会话卡片。
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  final GroupSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.groups, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('${session.agentIds.length} 名 Agent · '
                      '${session.messages.length} 条消息',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppColors.textMuted),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// 新建群聊底部弹窗：输入标题并勾选参与的（已启用）Agent。
class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({required this.agents, required this.onCreate});

  final List<Agent> agents;
  final Future<void> Function(String title, List<String> agentIds) onCreate;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final TextEditingController _title = TextEditingController();
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一名 Agent')),
      );
      return;
    }
    await widget.onCreate(_title.text, _selected.toList());
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
            const Text('新建群聊',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                labelText: '群聊名称',
                labelStyle: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('选择参与 Agent',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            if (widget.agents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('暂无已启用的 Agent，请先到 Agent 页新建',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.agents.length,
                itemBuilder: (BuildContext context, int index) {
                  final agent = widget.agents[index];
                  return CheckboxListTile(
                    value: _selected.contains(agent.id),
                    activeColor: AppColors.primary,
                    title: Text(agent.name,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary)),
                    subtitle: Text(agent.role.isEmpty ? '未设置身份' : agent.role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                    controlAffinity: ListTileControlAffinity.trailing,
                    onChanged: (bool? v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(agent.id);
                        } else {
                          _selected.remove(agent.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('创建')),
          ],
        ),
      ),
    );
  }
}

/// 群聊会话详情：多 Agent 并行流式回复。
class GroupChatView extends StatefulWidget {
  const GroupChatView({
    super.key,
    required this.session,
    required this.controller,
    required this.agents,
    required this.models,
  });

  final GroupSession session;
  final GroupController controller;
  final List<Agent> agents;
  final List<ModelConfig> models;

  @override
  State<GroupChatView> createState() => _GroupChatViewState();
}

class _GroupChatViewState extends State<GroupChatView> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _busy = false;

  String _genId() => DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  /// 解析参与群聊的、仍然存在且已启用的 Agent（按 session.agentIds 顺序）。
  List<Agent> _participants() {
    final byId = <String, Agent>{
      for (final a in widget.agents) a.id: a,
    };
    return widget.session.agentIds
        .map((id) => byId[id])
        .whereType<Agent>()
        .where((a) => a.enabled)
        .toList();
  }

  ModelConfig? _model(String modelId) {
    if (modelId.isEmpty) return null;
    for (final m in widget.models) {
      if (m.id == modelId) return m;
    }
    return null;
  }

  List<ChatMessage> _buildContext(Agent agent, List<GroupMessage> history) {
    return <ChatMessage>[
      if (agent.systemPrompt.trim().isNotEmpty)
        ChatMessage(
          id: 'sys-${agent.id}',
          role: ChatRole.system,
          content: agent.systemPrompt,
        ),
      for (final m in history)
        ChatMessage(
          id: m.id,
          role: m.isUser ? ChatRole.user : ChatRole.assistant,
          content: m.content,
        ),
    ];
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    final participants = _participants();
    if (participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可参与的 Agent，请先新建并启用 Agent')),
      );
      return;
    }

    _input.clear();
    final session = widget.session;
    // 用户消息
    session.messages.add(GroupMessage(
      id: _genId(),
      senderId: 'user',
      senderName: '我',
      content: text,
    ));
    // 上下文快照：不含尚未生成占位的其它 Agent 空回复，避免污染上下文
    final history = List<GroupMessage>.from(session.messages);

    // 为每个参与 Agent 建立流式占位消息
    final targets = <GroupMessage>[];
    for (final a in participants) {
      final m = GroupMessage(
        id: _genId(),
        senderId: a.id,
        senderName: a.name,
        content: '',
        streaming: true,
      );
      session.messages.add(m);
      targets.add(m);
    }
    session.updatedAt = DateTime.now();
    setState(() => _busy = true);

    await Future.wait(
      participants.asMap().entries.map(
            (e) => _runAgent(e.value, history, targets[e.key]),
          ),
    );

    await widget.controller.persist();
    if (mounted) {
      setState(() => _busy = false);
      _scrollToBottom();
    }
  }

  Future<void> _runAgent(
    Agent agent,
    List<GroupMessage> history,
    GroupMessage target,
  ) async {
    final model = _model(agent.modelId);
    if (model == null) {
      target.content = '[未找到关联模型，请为该 Agent 设置模型]';
      target.streaming = false;
      if (mounted) setState(() {});
      return;
    }
    try {
      await for (final delta in const LlmService().streamChat(
        model: model,
        messages: _buildContext(agent, history),
      )) {
        target.content += delta;
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (target.content.isEmpty) target.content = '调用失败：$e';
    } finally {
      target.streaming = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final participantCount = _participants().length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.title),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.surfaceLight,
            child: Text('参与 Agent：$participantCount 名',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: widget.session.messages.isEmpty
                ? const Center(
                    child: Text('发送一条消息，所有 Agent 将协同回复',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: widget.session.messages.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _GroupMessageBubble(
                        message: widget.session.messages[index],
                      );
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _input,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                cursorColor: AppColors.primaryLight,
                onSubmitted: (_) {
                  if (!_busy) _send();
                },
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _busy ? '各 Agent 正在回复…' : '输入消息，群里的 Agent 都会回复…',
                  hintStyle: const TextStyle(
                      fontSize: 14, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '发送',
              onPressed: _busy ? null : _send,
              icon: const Icon(Icons.send, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// 群聊消息气泡：区分用户与不同 Agent 的回复，助手回复用 Markdown 渲染。
class _GroupMessageBubble extends StatelessWidget {
  const _GroupMessageBubble({required this.message});
  final GroupMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(message.content,
              style: const TextStyle(
                  fontSize: 15, height: 1.5, color: Colors.white)),
        ),
      );
    }

    final streaming = message.streaming;
    final data = message.content.isEmpty && streaming
        ? '正在生成…'
        : (streaming ? '${message.content}▌' : message.content);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.smart_toy_outlined,
                    size: 13, color: AppColors.primaryLight),
                const SizedBox(width: 4),
                Text(message.senderName,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryLight)),
              ],
            ),
            const SizedBox(height: 6),
            if (message.content.isEmpty && streaming)
              const Text('正在生成…',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary))
            else
              MarkdownBody(
                data: data,
                selectable: true,
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: AppColors.textPrimary),
                  code: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: AppColors.accent,
                      backgroundColor: AppColors.background),
                ),
              ),
          ],
        ),
      ),
    );
  }
}