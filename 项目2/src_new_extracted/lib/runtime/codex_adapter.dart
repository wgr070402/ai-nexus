/// 一次对话消息（用于 Codex 上下文）。
class CodexMessage {
  const CodexMessage({required this.role, required this.content});

  /// `system` / `user` / `assistant`。
  final String role;
  final String content;
}

/// Codex 探测（连通性 / 鉴权）结果。
class CodexDetectResult {
  const CodexDetectResult({required this.available, this.message});

  final bool available;
  final String? message;
}

/// Codex 代码生成结果。
class CodexGenerateResult {
  const CodexGenerateResult({
    required this.success,
    this.output = '',
    this.model = '',
    this.error,
  });

  final bool success;

  /// 生成的代码 / 文本。
  final String output;

  /// 实际使用的模型。
  final String model;

  final String? error;

  factory CodexGenerateResult.failure(String error) => CodexGenerateResult(
        success: false,
        error: error,
      );
}

/// Codex 接口契约（独立 Adapter）。
///
/// 业务层只依赖本接口，不与具体传输（HTTP / 本地 Codex CLI / 云端）耦合，
/// 便于未来切换实现。所有失败均返回明确信息，绝不伪造生成结果。
abstract class CodexAdapter {
  /// 验证 API Key 与连通性。
  Future<CodexDetectResult> detect({required String apiKey});

  /// 生成代码 / 完成编码任务。
  Future<CodexGenerateResult> generate({
    required String apiKey,
    required String model,
    required String prompt,
    List<CodexMessage> history = const <CodexMessage>[],
  });
}