import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_models.dart';
import 'app_storage.dart';
import 'llm_service.dart';

/// 聊天状态控制器（ChangeNotifier）。
///
/// 负责：模型加载与切换、会话管理、消息发送与流式接收、本地持久化。
/// UI 通过 [ListenableBuilder] / [AnimatedBuilder] 监听本控制器刷新。
class ChatController extends ChangeNotifier {
  ChatController({this._llm = const LlmService()});

  final LlmService _llm;

  List<ModelConfig> _models = <ModelConfig>[];
  String? _activeModelId;
  List<ChatSession> _sessions = <ChatSession>[];
  String? _activeSessionId;

  bool _busy = false;
  String? _error;

  StreamSubscription<String>? _sub;
  Completer<void>? _done;

  bool get busy => _busy;
  String? get error => _error;
  List<ModelConfig> get models => _models;
  List<ChatSession> get sessions => _sessions;

  ModelConfig? get activeModel {
    for (final m in _models) {
      if (m.id == _activeModelId) return m;
    }
    return _models.isEmpty ? null : _models.first;
  }

  ChatSession? get activeSession {
    for (final s in _sessions) {
      if (s.id == _activeSessionId) return s;
    }
    return null;
  }

  List<ChatMessage> get messages => activeSession?.messages ?? const <ChatMessage>[];

  bool get hasActiveModel => activeModel != null;

  /// 初始化：加载模型、会话与当前选中项。
  Future<void> init() async {
    _models = await AppStorage.loadModels();
    final savedModelId = await AppStorage.activeModelId();
    if (savedModelId != null && _models.any((m) => m.id == savedModelId)) {
      _activeModelId = savedModelId;
    } else {
      _activeModelId = _models.isEmpty ? null : _models.first.id;
    }

    _sessions = await AppStorage.loadSessions();
    final savedSessionId = await AppStorage.activeSessionId();
    if (savedSessionId != null && _sessions.any((s) => s.id == savedSessionId)) {
      _activeSessionId = savedSessionId;
    } else if (_sessions.isNotEmpty) {
      _activeSessionId = _sessions.first.id;
    }
    notifyListeners();
  }

  // ---------- 模型 ----------

  void setActiveModel(String id) {
    _activeModelId = id;
    // 会话级记忆模型：当前会话绑定该模型，切换会话后可恢复。
    final session = activeSession;
    if (session != null) {
      session.modelId = id;
      _persistSessions();
    }
    AppStorage.setActiveModelId(id);
    notifyListeners();
  }

  Future<void> saveModel(ModelConfig model) async {
    await AppStorage.saveModel(model);
    _models = await AppStorage.loadModels();
    notifyListeners();
  }

  // ---------- 会话 ----------

  Future<void> newSession() async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final session = ChatSession(
      id: id,
      title: '新会话',
      modelId: _activeModelId ?? '',
    );
    _sessions.insert(0, session);
    _activeSessionId = id;
    await AppStorage.setActiveSessionId(id);
    await _persistSessions();
    notifyListeners();
  }

  Future<void> switchSession(String id) async {
    _activeSessionId = id;
    // 会话级记忆模型：切换到某会话时，恢复该会话绑定的模型。
    final session = activeSession;
    if (session != null &&
        session.modelId.isNotEmpty &&
        _models.any((m) => m.id == session.modelId)) {
      _activeModelId = session.modelId;
    }
    await AppStorage.setActiveSessionId(id);
    _error = null;
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    if (_activeSessionId == id) {
      _activeSessionId = _sessions.isEmpty ? null : _sessions.first.id;
      if (_activeSessionId != null) {
        await AppStorage.setActiveSessionId(_activeSessionId!);
      }
    }
    await _persistSessions();
    notifyListeners();
  }

  // ---------- 聊天 ----------

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 发送用户消息并流式接收助手回复。
  Future<void> sendMessage(String text,
      {List<ChatAttachment> attachments = const <ChatAttachment>[]}) async {
    final content = text.trim();
    if ((content.isEmpty && attachments.isEmpty) || _busy) return;

    final model = activeModel;
    if (model == null) {
      _error = '尚未选择模型';
      notifyListeners();
      return;
    }

    // 保证有当前会话
    if (activeSession == null) {
      await newSession();
    }
    final session = activeSession!;
    session.modelId = model.id;

    // 追加用户消息
    final userMsg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: _buildContent(content, attachments),
    );
    session.messages.add(userMsg);
    if (session.title == '新会话' || session.title.isEmpty) {
      final base = content.isNotEmpty
          ? content
          : (attachments.isNotEmpty ? attachments.first.name : '新会话');
      session.title = base.length > 20 ? '${base.substring(0, 20)}…' : base;
    }
    session.updatedAt = DateTime.now();

    // 追加流式助手占位
    final assistantMsg = ChatMessage(
      id: 'a${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.assistant,
      content: '',
      streaming: true,
    );
    session.messages.add(assistantMsg);

    _busy = true;
    _error = null;
    notifyListeners();
    await _persistSessions();

    final history = session.messages
        .where((m) => m.id != assistantMsg.id)
        .toList();

    final completer = Completer<void>();
    _done = completer;
    final buffer = StringBuffer();

    try {
      final stream = _llm.streamChat(model: model, messages: history);
      _sub = stream.listen(
        (delta) {
          buffer.write(delta);
          assistantMsg.content = buffer.toString();
          notifyListeners();
        },
        onError: (Object e) {
          assistantMsg.streaming = false;
          if (buffer.isEmpty) {
            assistantMsg.content = '请求失败：$e';
          } else {
            assistantMsg.content = '$buffer\n\n[流式中断：$e]';
          }
          _error = e.toString();
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          assistantMsg.streaming = false;
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future;
    } catch (e) {
      assistantMsg.streaming = false;
      if (assistantMsg.content.isEmpty) {
        assistantMsg.content = '请求失败：$e';
      }
      _error = e.toString();
    } finally {
      _sub = null;
      _done = null;
      _busy = false;
      session.updatedAt = DateTime.now();
      await _persistSessions();
      notifyListeners();
    }
  }

  /// 组装用户消息正文：文本 + 附件内容。
  ///
  /// 文本类附件以代码块包裹其内容供模型阅读；非文本附件仅标注文件名。
  static String _buildContent(String text, List<ChatAttachment> attachments) {
    final buf = StringBuffer();
    if (text.isNotEmpty) {
      buf.writeln(text);
      if (attachments.isNotEmpty) buf.writeln();
    }
    for (final a in attachments) {
      if (a.isText) {
        buf.writeln('【附件：${a.name}】');
        buf.writeln('```');
        buf.writeln(a.text);
        buf.writeln('```');
      } else {
        buf.writeln('【附件：${a.name}】'
            '（该类型内容已存于工作区，多模态识别待接入）');
      }
      buf.writeln();
    }
    return buf.toString().trim();
  }

  /// 停止当前流式生成。
  Future<void> stopGenerating() async {
    final sub = _sub;
    final completer = _done;
    if (sub != null) {
      await sub.cancel();
    }
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _persistSessions() => AppStorage.saveSessions(_sessions);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}