import 'runtime_result.dart';

/// DeepSeek Harness 探测结果。
class HarnessDetectResult {
  const HarnessDetectResult({
    required this.available,
    required this.version,
    this.compatible = false,
    this.message,
  });

  /// 服务是否可访问。
  final bool available;

  /// 服务端返回的 API 版本号字符串。
  final String version;

  /// 版本是否与本地支持一致。
  final bool compatible;

  /// 附加说明（不可用 / 版本不兼容时的可读信息）。
  final String? message;

  factory HarnessDetectResult.unavailable([String? message]) => HarnessDetectResult(
        available: false,
        version: '',
        compatible: false,
        message: message ?? 'DeepSeek Harness 未连接',
      );
}

/// DeepSeek Harness 会话。
class HarnessSession {
  const HarnessSession({required this.sessionId, required this.workspace});

  final String sessionId;
  final String workspace;
}

/// DeepSeek Harness 接口契约（独立 Adapter）。
///
/// 业务层只依赖本接口，不得依赖任何具体实现（HTTP 传输、进程内部细节等），
/// 以便未来切换本地 / 远程 / 云端 Harness 而不影响上层逻辑。
///
/// [detect] 返回 API 版本；当版本不兼容时必须返回明确的「版本不兼容」错误，
/// 禁止静默降级（策划书硬性要求）。
abstract class DeepSeekHarnessAdapter {
  /// 探测 Harness 是否可用及其 API 版本。
  Future<HarnessDetectResult> detect();

  /// 建立会话，成功返回 sessionId。
  Future<HarnessSession> connect({required String apiKey, required String workspace});

  /// 执行一段代码。
  Future<RuntimeResult> run({
    required String sessionId,
    required String code,
    required String language,
  });

  /// 执行测试命令。
  Future<RuntimeResult> test({
    required String sessionId,
    required String testCommand,
  });

  /// 取消当前会话中的任务。
  Future<bool> cancel(String sessionId);

  /// 断开并销毁会话。
  Future<bool> disconnect(String sessionId);
}