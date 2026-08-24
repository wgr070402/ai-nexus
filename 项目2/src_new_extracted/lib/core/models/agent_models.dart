import 'dart:convert';
import 'dart:developer' as dev;

/// 权限策略：一次高危操作如何处理。
enum PermissionPolicy {
  alwaysAllow('始终允许'),
  ask('每次询问'),
  deny('拒绝');

  const PermissionPolicy(this.label);
  final String label;

  static PermissionPolicy fromName(String? name) => PermissionPolicy.values.firstWhere(
        (p) => p.name == name,
        orElse: () => PermissionPolicy.ask,
      );
}

/// Agent 可被授予的权限类别（对齐策划书安全机制）。
enum AgentPermission {
  readFile('读取文件'),
  writeFile('写入文件'),
  deleteFile('删除文件'),
  runCommand('执行命令'),
  installPackage('安装软件'),
  networkAccess('网络访问'),
  sensitiveDir('访问敏感目录'),
  systemSettings('修改系统设置'),
  executeScript('执行脚本');

  const AgentPermission(this.label);
  final String label;

  static AgentPermission fromName(String? name) => AgentPermission.values.firstWhere(
        (p) => p.name == name,
        orElse: () => AgentPermission.readFile,
      );
}

/// 一个自定义 Agent（智能体）。
///
/// 含：身份/提示词/模型/技能/工具/权限/记忆/启停。Phase 3 起实现 CRUD 与基础权限。
class Agent {
  Agent({
    required this.id,
    required this.name,
    this.role = '',
    this.systemPrompt = '',
    this.modelId = '',
    List<String>? skills,
    List<String>? tools,
    Map<AgentPermission, PermissionPolicy>? permissions,
    Map<String, String>? memory,
    this.enabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : skills = skills ?? <String>[],
        tools = tools ?? <String>[],
        permissions = permissions ?? PermissionGuard.defaultPermissions(),
        memory = memory ?? <String, String>{},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  String role;
  String systemPrompt;
  String modelId;
  List<String> skills;
  List<String> tools;
  Map<AgentPermission, PermissionPolicy> permissions;
  Map<String, String> memory;
  bool enabled;
  final DateTime createdAt;
  DateTime updatedAt;

  Agent copyWith({
    String? name,
    String? role,
    String? systemPrompt,
    String? modelId,
    List<String>? skills,
    List<String>? tools,
    Map<AgentPermission, PermissionPolicy>? permissions,
    Map<String, String>? memory,
    bool? enabled,
  }) {
    return Agent(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      modelId: modelId ?? this.modelId,
      skills: skills ?? this.skills,
      tools: tools ?? this.tools,
      permissions: permissions ?? this.permissions,
      memory: memory ?? this.memory,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    dev.log(
      '序列化 Agent id=$id name=$name memory=${memory.length} '
      'entries=[${memory.keys.join(', ')}] permissions=${permissions.length}',
      name: 'AgentMemory',
    );
    return <String, dynamic>{
      'id': id,
      'name': name,
      'role': role,
      'systemPrompt': systemPrompt,
      'modelId': modelId,
      'skills': skills,
      'tools': tools,
      'permissions': permissions.map(
          (k, v) => MapEntry(k.name, v.name)),
      'memory': memory,
      'enabled': enabled,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Agent.fromJson(Map<String, dynamic> json) {
    final perms = <AgentPermission, PermissionPolicy>{};
    (json['permissions'] as Map<String, dynamic>? ?? <String, dynamic>{})
        .forEach((String k, dynamic v) {
      perms[AgentPermission.fromName(k)] = PermissionPolicy.fromName(v?.toString());
    });

    final mem = <String, String>{};
    final memRaw =
        json['memory'] as Map<String, dynamic>? ?? <String, dynamic>{};
    memRaw.forEach((String k, dynamic v) {
      final val = v?.toString() ?? '';
      mem[k] = val;
      dev.log('读取记忆项 key=$k value=$val', name: 'AgentMemory');
    });
    dev.log('解析记忆完成 条目数=${mem.length} keys=[${mem.keys.join(', ')}]',
        name: 'AgentMemory');

    return Agent(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '未命名 Agent',
      role: json['role']?.toString() ?? '',
      systemPrompt: json['systemPrompt']?.toString() ?? '',
      modelId: json['modelId']?.toString() ?? '',
      skills: (json['skills'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      tools: (json['tools'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      permissions: perms.isEmpty ? PermissionGuard.defaultPermissions() : perms,
      memory: mem,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['createdAt'] as num?)?.toInt() ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['updatedAt'] as num?)?.toInt() ?? 0),
    );
  }

  String encode() => jsonEncode(toJson());
}

/// 权限守卫：基础权限逻辑，评估 Agent 对某类操作是否放行。
///
/// 规则（策划书安全机制）：
/// - 高危操作（删文件/执行命令/装软件/访问敏感目录/改系统设置/执行脚本）默认需确认或拒绝；
/// - 默认禁用整个 Android 文件系统访问（sensitiveDir）与系统设置修改；
/// - 其余操作默认「每次询问」。
class PermissionGuard {
  const PermissionGuard._();

  /// 高危操作集合（需额外关注）。
  static const Set<AgentPermission> riskyPermissions = <AgentPermission>{
    AgentPermission.deleteFile,
    AgentPermission.runCommand,
    AgentPermission.installPackage,
    AgentPermission.sensitiveDir,
    AgentPermission.systemSettings,
    AgentPermission.executeScript,
  };

  /// 默认权限表：敏感目录访问与系统设置默认拒绝，其余默认询问。
  static Map<AgentPermission, PermissionPolicy> defaultPermissions() {
    return <AgentPermission, PermissionPolicy>{
      for (final p in AgentPermission.values)
        p: (p == AgentPermission.sensitiveDir || p == AgentPermission.systemSettings)
            ? PermissionPolicy.deny
            : PermissionPolicy.ask,
    };
  }

  /// 是否为高危操作。
  static bool isRisky(AgentPermission permission) =>
      riskyPermissions.contains(permission);

  /// 评估某权限的当前策略（未配置时回退默认值）。
  static PermissionPolicy evaluate(Agent agent, AgentPermission permission) {
    return agent.permissions[permission] ??
        defaultPermissions()[permission]!;
  }

  /// 是否放行（始终允许）。
  static bool allowed(Agent agent, AgentPermission permission) =>
      evaluate(agent, permission) == PermissionPolicy.alwaysAllow;

  /// 是否拒绝。
  static bool denied(Agent agent, AgentPermission permission) =>
      evaluate(agent, permission) == PermissionPolicy.deny;

  /// 是否需要二次确认（每次询问）。
  static bool requiresApproval(Agent agent, AgentPermission permission) =>
      evaluate(agent, permission) == PermissionPolicy.ask;
}