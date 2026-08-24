/// 一条知识库文档。
class KnowledgeDoc {
  KnowledgeDoc({
    required this.id,
    required this.title,
    this.content = '',
    this.category = '',
    List<String>? tags,
    this.sourceType = 'manual',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? <String>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String content;
  String category;
  final List<String> tags;

  /// 来源：`manual`（手写）/ `import`（导入）。
  String sourceType;

  DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'content': content,
        'category': category,
        'tags': tags,
        'sourceType': sourceType,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory KnowledgeDoc.fromJson(Map<String, dynamic> json) => KnowledgeDoc(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '未命名文档',
        content: json['content']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        tags: (json['tags'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => e.toString())
            .toList(),
        sourceType: json['sourceType']?.toString() ?? 'manual',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['createdAt'] as num?)?.toInt() ?? 0,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['updatedAt'] as num?)?.toInt() ?? 0,
        ),
      );
}