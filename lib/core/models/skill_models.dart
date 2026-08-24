/// 一条可复用技能（提示词/指令模板）。
class Skill {
  Skill({
    required this.id,
    required this.name,
    this.description = '',
    this.instruction = '',
    this.category = '',
    this.enabled = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  String description;

  /// 技能核心指令（提示词模板）。
  String instruction;

  String category;
  bool enabled;
  DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'instruction': instruction,
        'category': category,
        'enabled': enabled,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '未命名技能',
        description: json['description']?.toString() ?? '',
        instruction: json['instruction']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        enabled: json['enabled'] as bool? ?? true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['createdAt'] as num?)?.toInt() ?? 0,
        ),
      );
}