import 'dart:convert';

/// 聊天角色。
enum ChatRole {
  user,
  assistant,
  system;

  /// OpenAI 兼容协议中的角色名。
  String get apiName => switch (this) {
        ChatRole.user => 'user',
        ChatRole.assistant => 'assistant',
        ChatRole.system => 'system',
      };

  static ChatRole fromApi(String value) => switch (value) {
        'assistant' => ChatRole.assistant,
        'system' => ChatRole.system,
        _ => ChatRole.user,
      };
}

/// 一条聊天消息。
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.streaming = false,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final ChatRole role;
  String content;
  final DateTime createdAt;

  /// 是否正在流式生成（仅内存态，不持久化）。
  bool streaming;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'role': role.name,
        'content': content,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleName = json['role']?.toString() ?? 'user';
    final role = ChatRole.values.firstWhere(
      (r) => r.name == roleName,
      orElse: () => ChatRole.user,
    );
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      role: role,
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// 一次会话（单聊）。
class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    List<ChatMessage>? messages,
    this.modelId = '',
    DateTime? updatedAt,
  })  : messages = messages ?? <ChatMessage>[],
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  final List<ChatMessage> messages;
  String modelId;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'modelId': modelId,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final messages = (json['messages'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
    return ChatSession(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '新会话',
      modelId: json['modelId']?.toString() ?? '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num?)?.toInt() ?? 0,
      ),
      messages: messages,
    );
  }
}

/// 模型配置（不含密钥；密钥单独存于安全存储）。
class ModelConfig {
  const ModelConfig({
    required this.id,
    required this.name,
    required this.provider,
    required this.baseUrl,
    required this.model,
    this.apiKey = '',
    this.requiresKey = true,
  });

  final String id;
  final String name;

  /// 服务商标识，如 deepseek / openai / moonshot / zhipu / qwen / openrouter / ollama / custom。
  final String provider;

  /// OpenAI 兼容 API 端点（含 /v1 或 /v4 前缀）。
  final String baseUrl;

  /// 模型名称。
  final String model;

  /// 运行时注入的 API Key（从安全存储读取，不写入普通首选项）。
  final String apiKey;

  /// 是否需要 API Key（Ollama 本地模型可不需）。
  final bool requiresKey;

  ModelConfig copyWith({
    String? id,
    String? name,
    String? provider,
    String? baseUrl,
    String? model,
    String? apiKey,
    bool? requiresKey,
  }) {
    return ModelConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      requiresKey: requiresKey ?? this.requiresKey,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'provider': provider,
        'baseUrl': baseUrl,
        'model': model,
        'requiresKey': requiresKey,
      };

  factory ModelConfig.fromJson(Map<String, dynamic> json) => ModelConfig(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        provider: json['provider']?.toString() ?? 'custom',
        baseUrl: json['baseUrl']?.toString() ?? '',
        model: json['model']?.toString() ?? '',
        requiresKey: json['requiresKey'] as bool? ?? true,
      );

  /// 序列化模型配置为 JSON 字符串（供持久化）。
  String encode() => jsonEncode(toJson());
}

/// 聊天附件（发送给 AI 的文件/图片/压缩包）。
///
/// 仅文本类附件会把内容拼进消息正文供模型阅读；图片/压缩包等非文本
/// 附件以引用方式标注（多模态识别待后续接入，不伪造）。
class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.path,
    this.text = '',
  });

  final String name;
  final String path;

  /// 文本类附件的可读内容；为空表示非文本附件。
  final String text;

  bool get isText => text.isNotEmpty;
}