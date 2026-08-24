import 'dart:developer' as dev;

/// 一条终端命令记录。
class TermCommand {
  TermCommand({
    required this.command,
    required this.executor,
    this.output = '',
    this.error = '',
    this.exitCode,
    this.done = false,
  });

  final String command;

  /// 实际执行通道（local / termux）。
  String executor;
  String output;
  String error;
  int? exitCode;
  bool done;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'command': command,
        'executor': executor,
        'output': output,
        'error': error,
        'exitCode': exitCode,
        'done': done,
      };

  factory TermCommand.fromJson(Map<String, dynamic> json) => TermCommand(
        command: json['command']?.toString() ?? '',
        executor: json['executor']?.toString() ?? 'local',
        output: json['output']?.toString() ?? '',
        error: json['error']?.toString() ?? '',
        exitCode: (json['exitCode'] as num?)?.toInt(),
        done: json['done'] == true,
      );
}

/// 一个终端会话：含命令记录与命令历史，支持持久化。
class TermSession {
  TermSession({
    required this.id,
    required this.name,
    List<TermCommand>? commands,
    List<String>? history,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : commands = commands ?? <TermCommand>[],
        history = history ?? <String>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;

  /// 会话内的全部命令交互记录。
  final List<TermCommand> commands;

  /// 命令历史（用于上下键导航，最多保留 100 条）。
  final List<String> history;

  DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() {
    dev.log(
      '序列化会话 id=$id name=$name commands=${commands.length} history=${history.length}',
      name: 'TerminalSession',
    );
    return <String, dynamic>{
      'id': id,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'history': history,
      'commands': commands.map((c) => c.toJson()).toList(),
    };
  }

  factory TermSession.fromJson(Map<String, dynamic> json) {
    final commands = (json['commands'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(TermCommand.fromJson)
        .toList();
    final history = (json['history'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => e.toString())
        .toList();
    final session = TermSession(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '会话',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num?)?.toInt() ?? 0,
      ),
      commands: commands,
      history: history,
    );
    dev.log(
      '解析会话 id=${session.id} name=${session.name} '
      'commands=${commands.length} history=${history.length}',
      name: 'TerminalSession',
    );
    return session;
  }
}