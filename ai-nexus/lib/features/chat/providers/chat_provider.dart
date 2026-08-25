import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/chat_models.dart';
import '../../../core/models/model_config.dart';
import '../../../core/services/chat_service.dart';

/// 聊天状态
class ChatState {
  const ChatState({
    required this.messages,
    required this.isStreaming,
    required this.currentModel,
  });

  final List<ChatMessage> messages;
  final bool isStreaming;
  final ModelConfig currentModel;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    ModelConfig? currentModel,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      currentModel: currentModel ?? this.currentModel,
    );
  }
}

/// 默认模型（DeepSeek），后续从设置读取
const ModelConfig kDefaultModel = ModelConfig(
  id: 'deepseek-chat',
  provider: 'deepseek',
  apiKey: '', // 运行时从凭据读取
  baseUrl: 'https://api.deepseek.com/v1',
  modelName: 'deepseek-chat',
);

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.watch(chatServiceProvider), kDefaultModel);
});

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._service, ModelConfig initialModel)
      : super(ChatState(
          messages: const [],
          isStreaming: false,
          currentModel: initialModel,
        ));

  final ChatService _service;
  CancelToken? _cancelToken;

  static String _genId() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  /// 发送一条用户消息，并流式接收助手回复
  Future<void> send(String text) async {
    if (text.trim().isEmpty || state.isStreaming) return;

    final userMsg = ChatMessage(
      id: _genId(),
      role: ChatRole.user,
      content: text,
      createdAt: DateTime.now(),
    );
    final assistantId = _genId();
    final assistantMsg = ChatMessage(
      id: assistantId,
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime.now(),
    );

    final history = [...state.messages, userMsg];
    state = state.copyWith(
      messages: [...history, assistantMsg],
      isStreaming: true,
    );

    await _streamReply(history, assistantId);
  }

  /// 流式接收回复并更新助手消息
  Future<void> _streamReply(
      List<ChatMessage> requestMessages, String assistantId) async {
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final buffer = StringBuffer();

    try {
      await for (final chunk in _service.chat(
        cfg: state.currentModel,
        messages: requestMessages,
        cancelToken: cancelToken,
      )) {
        if (chunk.isDone) break;
        buffer.write(chunk.delta);
        _updateAssistant(assistantId, buffer.toString());
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _updateAssistant(assistantId, buffer.toString(), interrupted: true);
        return;
      }
      _updateAssistant(assistantId, '请求失败：${e.message}');
    } catch (e) {
      _updateAssistant(assistantId, '发生错误：$e');
    } finally {
      state = state.copyWith(isStreaming: false);
      _cancelToken = null;
    }
  }

  /// 流式中切模型：中断当前流 + 用新模型重答当前这一条
  void switchModel(ModelConfig newModel) {
    if (state.isStreaming) {
      // 中断当前流
      _cancelToken?.cancel();
      // 找到最后一条用户消息
      final users = state.messages
          .where((m) => m.role == ChatRole.user)
          .toList();
      if (users.isEmpty) {
        state = state.copyWith(currentModel: newModel);
        return;
      }
      final lastUser = users.last;
      state = state.copyWith(currentModel: newModel);
      // 用新模型重答（中断当前流会异步结束，重答在其后）
      _resendAfterSwitch(lastUser);
    } else {
      state = state.copyWith(currentModel: newModel);
    }
  }

  Future<void> _resendAfterSwitch(ChatMessage lastUser) async {
    // 等待当前流真正结束（已 cancel）
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // 去掉之前的助手回复（被中断的那条），重新生成
    final users = state.messages
        .where((m) => m.role == ChatRole.user)
        .toList();
    final history = users; // 只用历史用户消息作为上下文
    final assistantId = _genId();
    final assistantMsg = ChatMessage(
      id: assistantId,
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, assistantMsg],
      isStreaming: true,
    );
    await _streamReply(history, assistantId);
  }

  void _updateAssistant(String id, String content, {bool interrupted = false}) {
    final msgs = state.messages.map((m) {
      if (m.id == id) {
        return m.copyWith(content: content, isInterrupted: interrupted);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: msgs);
  }
}
