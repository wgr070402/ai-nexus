import 'runtime_result.dart';

/// 运行时识别结果。
class RuntimeDetectResult {
  const RuntimeDetectResult({
    required this.language,
    required this.projectType,
    this.recommendedRuntime = '',
  });

  /// 语言：python / javascript / typescript / rust / go / c / cpp / java / kotlin / unknown。
  final String language;

  /// 项目类型：如 python-pip / node-npm / rust-cargo / go-mod / cmake / make / maven / gradle。
  final String projectType;

  /// 推荐运行时：termux（Android 本地）/ remote（远程 PC/云端）/ none。
  final String recommendedRuntime;

  bool get detected => language != 'unknown';
}

/// 依赖检查结果。
class DependencyCheckResult {
  const DependencyCheckResult({required this.installed, required this.missing});

  final List<String> installed;
  final List<String> missing;

  bool get ok => missing.isEmpty;
}

/// Runtime 接口契约：统一执行环境调度器。
///
/// 业务层只依赖本接口，不依赖具体实现。Android 本地优先 Termux，
/// Termux 不可用时由实现切到 Remote PC / SSH / Cloud（策划书 V2 增强规格）。
abstract class RuntimeAdapter {
  /// 识别项目语言 / 类型与推荐运行时。
  Future<RuntimeDetectResult> detect({required String projectPath});

  /// 检查运行所需依赖是否就绪。
  Future<DependencyCheckResult> checkDeps({
    required RuntimeDetectResult detection,
    String? workspace,
  });

  /// 构建。
  Future<RuntimeResult> build({required String sessionId, required String workspace});

  /// 运行。
  Future<RuntimeResult> run({
    required String sessionId,
    required String workspace,
    String? command,
  });

  /// 测试。
  Future<RuntimeResult> test({
    required String sessionId,
    required String workspace,
    String? command,
  });

  /// 取消当前会话任务。
  Future<bool> cancel(String sessionId);
}