/// 群聊（Multi-Agent）中的一条消息。
///
/// [senderId] 为 `user` 时表示用户，否则为参与对话的 Agent id。
class GroupMessage {
  GroupMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    DateTime? createdAt,
    this.streaming = false,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String senderId;
  final String senderName;
  String content;
  final DateTime createdAt;

  /// 仅内存态标记（是否正在流式生成），不持久化。
  bool streaming;

  bool get isUser => senderId == 'user';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory GroupMessage.fromJson(Map<String, dynamic> json) => GroupMessage(
        id: json['id']?.toString() ?? '',
        senderId: json['senderId']?.toString() ?? 'user',
        senderName: json['senderName']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['createdAt'] as num?)?.toInt() ?? 0,
        ),
      );
}

/// 一个多智能体群聊会话。
class GroupSession {
  GroupSession({
    required this.id,
    required this.title,
    List<String>? agentIds,
    List<GroupMessage>? messages,
    DateTime? updatedAt,
  })  : agentIds = agentIds ?? <String>[],
        messages = messages ?? <GroupMessage>[],
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;

  /// 参与群聊的 Agent id（有序，决定回复顺序展示）。
  final List<String> agentIds;

  final List<GroupMessage> messages;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'agentIds': agentIds,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory GroupSession.fromJson(Map<String, dynamic> json) {
    final messages = (json['messages'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(GroupMessage.fromJson)
        .toList();
    return GroupSession(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '新群聊',
      agentIds: (json['agentIds'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num?)?.toInt() ?? 0,
      ),
      messages: messages,
    );
  }
}