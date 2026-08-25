/// 聊天角色
enum ChatRole { user, assistant, system }

/// 单条消息
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isInterrupted = false, // 流式中被「切模型」中断标记
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final bool isInterrupted;

  ChatMessage copyWith({
    String? content,
    bool? isInterrupted,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      isInterrupted: isInterrupted ?? this.isInterrupted,
    );
  }
}

/// 会话
class Conversation {
  Conversation({
    required this.id,
    required this.title,
    required this.modelId,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  final String id;
  String title;
  final String modelId;
  final List<ChatMessage> messages;
}

/// 流式输出块（SSE 解析结果）
class StreamChunk {
  const StreamChunk({required this.delta, this.isDone = false});

  final String delta; // 增量文本
  final bool isDone; // 是否结束
}
