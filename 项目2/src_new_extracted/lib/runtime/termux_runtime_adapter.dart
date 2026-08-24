import '../services/termux_bridge.dart';
import 'runtime_adapter.dart';
import 'runtime_detector.dart';
import 'runtime_result.dart';

/// 基于 Termux 的 RuntimeAdapter 具体实现。
///
/// - 识别：通过 Termux 列目录后交给 [RuntimeDetector] 静态识别；
/// - 依赖检查 / 构建 / 运行 / 测试：通过 TermuxBridge 执行真实命令；
/// - 未装 Termux 时回退本地 shell（能力有限），结果均如实返回，绝不伪造。
class TermuxRuntimeAdapter implements RuntimeAdapter {
  const TermuxRuntimeAdapter();

  @override
  Future<RuntimeDetectResult> detect({required String projectPath}) async {
    final r = await TermuxBridge.execute(
      command: 'ls -A "$projectPath" 2>/dev/null',
      useTermux: true,
    );
    if (!r.success || r.stdout.trim().isEmpty) {
      return const RuntimeDetectResult(
          language: 'unknown', projectType: 'unknown', recommendedRuntime: '');
    }
    final files = r.stdout
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return RuntimeDetector.detect(files);
  }

  @override
  Future<DependencyCheckResult> checkDeps({
    required RuntimeDetectResult detection,
    String? workspace,
  }) async {
    final required = _requiredCommands(detection);
    final installed = <String>[];
    final missing = <String>[];
    for (final cmd in required) {
      final r = await TermuxBridge.execute(command: '$cmd --version', useTermux: true);
      if (r.success) {
        installed.add(cmd);
      } else {
        missing.add(cmd);
      }
    }
    return DependencyCheckResult(installed: installed, missing: missing);
  }

  @override
  Future<RuntimeResult> build({required String sessionId, required String workspace}) =>
      _exec(sessionId, workspace, 'cd "$workspace" && make 2>&1');

  @override
  Future<RuntimeResult> run({
    required String sessionId,
    required String workspace,
    String? command,
  }) =>
      _exec(sessionId, workspace, command ?? 'cd "$workspace" && bash run.sh 2>&1');

  @override
  Future<RuntimeResult> test({
    required String sessionId,
    required String workspace,
    String? command,
  }) =>
      _exec(sessionId, workspace, command ?? 'cd "$workspace" && make test 2>&1');

  @override
  Future<bool> cancel(String sessionId) => TermuxBridge.kill(sessionId);

  Future<RuntimeResult> _exec(String sessionId, String workspace, String command) async {
    final sw = Stopwatch()..start();
    final r = await TermuxBridge.execute(
      command: command,
      sessionId: sessionId,
      useTermux: true,
    );
    sw.stop();
    return RuntimeResult(
      success: r.success,
      runtime: r.executor,
      exitCode: r.exitCode,
      command: command,
      stdout: r.stdout,
      stderr: r.stderr,
      duration: sw.elapsed,
      errorSummary: r.success
          ? null
          : (r.stderr.trim().isEmpty ? 'exit ${r.exitCode}' : r.stderr.trim()),
    );
  }

  static List<String> _requiredCommands(RuntimeDetectResult d) {
    switch (d.language) {
      case 'python':
        return <String>['python3'];
      case 'javascript':
      case 'typescript':
        return <String>['node'];
      case 'rust':
        return <String>['cargo'];
      case 'go':
        return <String>['go'];
      case 'c/cpp':
        return <String>['gcc'];
      case 'java':
      case 'kotlin':
        return <String>['java'];
      default:
        return <String>[];
    }
  }
}