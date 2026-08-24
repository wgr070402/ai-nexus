/// 工作流中的一步。
///
/// [agentId] 为空表示由编排层读取「当前默认模型」执行；否则指定某 Agent 专家。
class WorkflowStep {
  WorkflowStep({
    required this.id,
    required this.name,
    this.prompt = '',
    this.agentId = '',
  });

  final String id;
  String name;

  /// 该步的指令（提示词），可引用上文（上一步输出会自动拼入上下文）。
  String prompt;

  /// 指派的 Agent id（空串表示未指定）。
  String agentId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'prompt': prompt,
        'agentId': agentId,
      };

  factory WorkflowStep.fromJson(Map<String, dynamic> json) => WorkflowStep(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        prompt: json['prompt']?.toString() ?? '',
        agentId: json['agentId']?.toString() ?? '',
      );
}

/// 一个多智能体工作流：有序步骤序列，逐步执行、上下文链式传递。
class Workflow {
  Workflow({
    required this.id,
    required this.title,
    this.description = '',
    List<WorkflowStep>? steps,
    DateTime? updatedAt,
  })  : steps = steps ?? <WorkflowStep>[],
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String description;
  final List<WorkflowStep> steps;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'description': description,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  factory Workflow.fromJson(Map<String, dynamic> json) {
    final steps = (json['steps'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(WorkflowStep.fromJson)
        .toList();
    return Workflow(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '未命名工作流',
      description: json['description']?.toString() ?? '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num?)?.toInt() ?? 0,
      ),
      steps: steps,
    );
  }
}