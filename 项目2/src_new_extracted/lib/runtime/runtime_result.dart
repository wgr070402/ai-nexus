/// 运行时统一执行结果模型。
///
/// 所有「执行类」能力（DeepSeek Harness / Runtime Manager / 环境管理器等）
/// 统一返回本模型，便于上层业务无差别消费执行结果。
class RuntimeResult {
  const RuntimeResult({
    required this.success,
    required this.runtime,
    this.exitCode,
    this.command = '',
    this.stdout = '',
    this.stderr = '',
    this.duration,
    this.testPassed,
    this.testsTotal,
    this.testsFailed,
    this.artifacts = const <String>[],
    this.changedFiles = const <String>[],
    this.errorSummary,
  });

  /// 是否整体成功（测试场景下还需结合 testsTotal / testsFailed 判断）。
  final bool success;

  /// 实际执行运行时标识，如 `local` / `termux` / `deepseek-harness`。
  final String runtime;

  final int? exitCode;
  final String command;
  final String stdout;
  final String stderr;
  final Duration? duration;

  final int? testPassed;
  final int? testsTotal;
  final int? testsFailed;

  /// 产物文件路径列表。
  final List<String> artifacts;

  /// 本次执行中被改动的文件路径列表。
  final List<String> changedFiles;

  /// 失败时的简短可读错误摘要。
  final String? errorSummary;

  factory RuntimeResult.fromMap(Map<String, dynamic> map) => RuntimeResult(
        success: map['success'] == true,
        runtime: (map['runtime'] ?? '').toString(),
        exitCode: (map['exitCode'] as num?)?.toInt(),
        command: (map['command'] ?? '').toString(),
        stdout: (map['stdout'] ?? '').toString(),
        stderr: (map['stderr'] ?? '').toString(),
        duration: _toDuration(map['duration']),
        testPassed: (map['testPassed'] as num?)?.toInt(),
        testsTotal: (map['testsTotal'] as num?)?.toInt(),
        testsFailed: (map['testsFailed'] as num?)?.toInt(),
        artifacts: _toStringList(map['artifacts']),
        changedFiles: _toStringList(map['changedFiles']),
        errorSummary: map['errorSummary']?.toString(),
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'success': success,
        'runtime': runtime,
        'exitCode': exitCode,
        'command': command,
        'stdout': stdout,
        'stderr': stderr,
        'duration': duration?.inMilliseconds,
        'testPassed': testPassed,
        'testsTotal': testsTotal,
        'testsFailed': testsFailed,
        'artifacts': artifacts,
        'changedFiles': changedFiles,
        'errorSummary': errorSummary,
      };

  static Duration? _toDuration(dynamic value) {
    if (value is num) return Duration(milliseconds: value.toInt());
    return null;
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const <String>[];
  }
}