import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app/theme.dart';
import '../../core/models/chat_models.dart';
import '../../core/services/chat_controller.dart';

/// 单聊会话页：接入 LLM 服务，实现流式对话、Markdown 渲染、
/// 会话历史管理、模型选择与 API Key 配置。
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatController _chat = ChatController();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _chat.addListener(_onChatChanged);
    _chat.init();
  }

  @override
  void dispose() {
    _chat.removeListener(_onChatChanged);
    _chat.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChatChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await _chat.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_chat.activeModel?.name ?? '单聊'),
        actions: <Widget>[
          IconButton(
            tooltip: '选择模型',
            onPressed: _chat.busy ? null : _openModelPicker,
            icon: const Icon(Icons.smart_toy_outlined),
          ),
          IconButton(
            tooltip: '新会话',
            onPressed: _chat.busy ? null : _chat.newSession,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: _buildDrawer(),
      ),
      body: ListenableBuilder(
        listenable: _chat,
        builder: (BuildContext context, _) {
          return Column(
            children: <Widget>[
              if (_chat.error != null) _buildErrorBar(_chat.error!),
              Expanded(child: _buildMessages()),
              _buildInputBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDrawer() {
    return SafeArea(
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Icon(Icons.forum_outlined, color: AppColors.primaryLight),
                SizedBox(width: 10),
                Text('会话历史',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _chat.sessions.isEmpty
                ? const Center(
                    child: Text('暂无会话',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    itemCount: _chat.sessions.length,
                    itemBuilder: (BuildContext context, int index) {
                      final session = _chat.sessions[index];
                      final selected = session.id == _chat.activeSession?.id;
                      return ListTile(
                        selected: selected,
                        selectedColor: AppColors.primaryLight,
                        title: Text(session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.textPrimary)),
                        subtitle: Text(
                          '${session.messages.length} 条消息',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: AppColors.textMuted),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _chat.deleteSession(session.id);
                          },
                        ),
                        onTap: () {
                          _chat.switchSession(session.id);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBar(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.danger.withValues(alpha: 0.12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(error,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.danger)),
          ),
          InkWell(
            onTap: _chat.clearError,
            child: const Icon(Icons.close, size: 16, color: AppColors.danger),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    final messages = _chat.messages;
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.chat_bubble_outline,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              const Text('开始你的对话',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(
                _chat.hasActiveModel
                    ? '下方输入消息，模型将流式回复'
                    : '请先点击右上角选择并配置模型',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: messages.length,
      itemBuilder: (BuildContext context, int index) {
        return _MessageBubble(message: messages[index]);
      },
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
                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                cursorColor: AppColors.primaryLight,
                onSubmitted: (_) {
                  if (!_chat.busy) _send();
                },
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _chat.busy ? '正在生成…' : '输入消息…',
                  hintStyle:
                      const TextStyle(fontSize: 14, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            if (_chat.busy)
              IconButton.filled(
                tooltip: '停止',
                onPressed: _chat.stopGenerating,
                icon: const Icon(Icons.stop, size: 20),
              )
            else
              IconButton.filled(
                tooltip: '发送',
                onPressed: _chat.hasActiveModel ? _send : _openModelPicker,
                icon: const Icon(Icons.send, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- 模型选择 ----------

  void _openModelPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => _ModelPickerSheet(
        chat: _chat,
        onEdit: _openModelEditor,
      ),
    ).then((_) => setState(() {}));
  }

  Future<void> _openModelEditor(ModelConfig model) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => _ModelEditorSheet(
        chat: _chat,
        model: model,
      ),
    );
    setState(() {});
  }
}

/// 将 Markdown 源码尽量还原为纯文本（用于「复制纯文本」）。
String stripMarkdown(String markdown) {
  var s = markdown;
  // 代码块（含语言标记）
  s = s.replaceAll(RegExp(r'```[\s\S]*?```'), ' [代码块] ');
  // 行内代码
  s = s.replaceAll(RegExp(r'`([^`]*)`'), r'$1');
  // 标题
  s = s.replaceAll(RegExp(r'^#{1,6}[ \t]+', multiLine: true), '');
  // 粗体 / 斜体 / 删除线
  s = s.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
  s = s.replaceAll(RegExp(r'__([^_]+)__'), r'$1');
  s = s.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
  s = s.replaceAll(RegExp(r'_([^_]+)_'), r'$1');
  s = s.replaceAll(RegExp(r'~~([^~]+)~~'), r'$1');
  // 链接 / 图片
  s = s.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), r'$1');
  s = s.replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1');
  // 引用
  s = s.replaceAll(RegExp(r'^>[ \t]?', multiLine: true), '');
  // 列表
  s = s.replaceAll(RegExp(r'^[ \t]*[-*+][ \t]+', multiLine: true), '• ');
  s = s.replaceAll(RegExp(r'^[ \t]*\d+[.)][ \t]+', multiLine: true), '');
  // 分隔线
  s = s.replaceAll(RegExp(r'^[ \t]*([-*_])([ \t]*\1){2,}[ \t]*$', multiLine: true), '');
  return s.trim();
}

/// 消息气泡。
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  bool get _isUser => message.role == ChatRole.user;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showCopyMenu(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          decoration: BoxDecoration(
            color: _isUser ? AppColors.primaryDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(_isUser ? 14 : 4),
              bottomRight: Radius.circular(_isUser ? 4 : 14),
            ),
            border: _isUser ? null : Border.all(color: AppColors.border),
          ),
          child: _isUser
              ? Text(message.content,
                  style: const TextStyle(
                      fontSize: 15, height: 1.5, color: Colors.white))
              : _AssistantContent(message: message),
        ),
      ),
    );
  }

  /// 长按弹出复制菜单：复制纯文本 / 复制 Markdown 源码。
  Future<void> _showCopyMenu(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.copy_all_outlined,
                  color: AppColors.primaryLight),
              title: const Text('复制纯文本',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              onTap: () => Navigator.of(context).pop('plain'),
            ),
            ListTile(
              leading: const Icon(Icons.code_outlined,
                  color: AppColors.primaryLight),
              title: const Text('复制 Markdown 源码',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              onTap: () => Navigator.of(context).pop('markdown'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    final isPlain = action == 'plain';
    final text = isPlain ? stripMarkdown(message.content) : message.content;
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isPlain ? '已复制纯文本' : '已复制 Markdown 源码')),
    );
  }
}

/// 助手消息内容：流式光标 + Markdown。
class _AssistantContent extends StatelessWidget {
  const _AssistantContent({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final streaming = message.streaming;
    if (message.content.isEmpty && streaming) {
      return const _TypingIndicator();
    }

    final data = streaming ? '${message.content}▌' : message.content;

    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: const TextStyle(
            fontSize: 15, height: 1.55, color: AppColors.textPrimary),
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
        blockquoteDecoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(
            left: BorderSide(color: AppColors.primary, width: 3),
          ),
        ),
      ),
    );
  }
}

/// 生成中的三点提示。
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final int dots = ((_controller.value * 3).floor() % 3) + 1;
        return Text('正在生成${'.' * dots}',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary));
      },
    );
  }
}

/// 模型选择底部弹窗。
class _ModelPickerSheet extends StatelessWidget {
  const _ModelPickerSheet({required this.chat, required this.onEdit});
  final ChatController chat;
  final void Function(ModelConfig) onEdit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('选择模型',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: chat.models.length,
              itemBuilder: (BuildContext context, int index) {
                final model = chat.models[index];
                final selected = model.id == chat.activeModel?.id;
                return ListTile(
                  selected: selected,
                  selectedColor: AppColors.primaryLight,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.smart_toy_outlined,
                        size: 18, color: AppColors.primaryLight),
                  ),
                  title: Text(model.name,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textPrimary)),
                  subtitle: Text(model.model,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (model.requiresKey && model.apiKey.isEmpty)
                        const Icon(Icons.key_off,
                            size: 16, color: AppColors.warning),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onEdit(model);
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    chat.setActiveModel(model.id);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 模型配置编辑弹窗（名称 / 端点 / 模型 / API Key）。
class _ModelEditorSheet extends StatefulWidget {
  const _ModelEditorSheet({required this.chat, required this.model});
  final ChatController chat;
  final ModelConfig model;

  @override
  State<_ModelEditorSheet> createState() => _ModelEditorSheetState();
}

class _ModelEditorSheetState extends State<_ModelEditorSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.model.name);
  late final TextEditingController _baseUrl =
      TextEditingController(text: widget.model.baseUrl);
  late final TextEditingController _model =
      TextEditingController(text: widget.model.model);
  late final TextEditingController _apiKey =
      TextEditingController(text: widget.model.apiKey);

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(widget.model.name,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            _field(_name, '显示名称'),
            const SizedBox(height: 12),
            _field(_baseUrl, 'API 端点 (baseUrl)'),
            const SizedBox(height: 12),
            _field(_model, '模型名称'),
            const SizedBox(height: 12),
            _field(_apiKey, 'API Key', obscure: true),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final updated = widget.model.copyWith(
                  name: _name.text.trim().isEmpty ? widget.model.name : _name.text.trim(),
                  baseUrl: _baseUrl.text.trim(),
                  model: _model.text.trim().isEmpty ? widget.model.model : _model.text.trim(),
                  apiKey: _apiKey.text.trim(),
                );
                await widget.chat.saveModel(updated);
                if (mounted) Navigator.of(this.context).pop();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
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
      ),
    );
  }
}