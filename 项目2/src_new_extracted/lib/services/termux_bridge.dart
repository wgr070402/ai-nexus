import 'package:flutter/services.dart';

/// Termux 环境检测结果。
class TermuxStatus {
  const TermuxStatus({
    required this.termux,
    required this.termuxVersion,
    required this.termuxApi,
    required this.termuxApiVersion,
    this.termuxSha256 = '',
    this.termuxSignatureValid = false,
  });

  final bool termux;
  final String termuxVersion;
  final bool termuxApi;
  final String termuxApiVersion;

  /// Termux 签名证书 SHA-256（十六进制大写，未安装时为空）。
  final String termuxSha256;

  /// 是否为官方（F-Droid / GitHub Release）签名。
  final bool termuxSignatureValid;

  /// Termux 与 Termux:API 是否都已安装（两者是独立 App，缺一不可）。
  bool get ready => termux && termuxApi;

  /// Termux 已装且签名为官方可信签名。
  bool get signatureOk => termux && termuxSignatureValid;

  factory TermuxStatus.fromMap(Map<dynamic, dynamic> map) => TermuxStatus(
        termux: map['termux'] == true,
        termuxVersion: map['termuxVersion']?.toString() ?? '',
        termuxApi: map['termuxApi'] == true,
        termuxApiVersion: map['termuxApiVersion']?.toString() ?? '',
        termuxSha256: map['termuxSha256']?.toString() ?? '',
        termuxSignatureValid: map['termuxSignatureValid'] == true,
      );
}

/// 一次命令执行的结构化结果。
class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.sessionId,
    required this.executor,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final String sessionId;

  /// 实际执行通道：local（本地 shell）/ termux / none。
  final String executor;

  bool get success => exitCode == 0;

  factory CommandResult.fromMap(Map<dynamic, dynamic> map) => CommandResult(
        exitCode: (map['exitCode'] as num?)?.toInt() ?? -1,
        stdout: map['stdout']?.toString() ?? '',
        stderr: map['stderr']?.toString() ?? '',
        sessionId: map['sessionId']?.toString() ?? '',
        executor: map['executor']?.toString() ?? 'local',
      );
}

/// 终端桥接层：与 Android 原生 TermuxBridge 通信。
///
/// MethodChannel 名约定为 `com.ai-nexus/termux`（策划书约定）。
class TermuxBridge {
  const TermuxBridge._();

  static const MethodChannel _channel = MethodChannel('com.ai-nexus/termux');

  /// 检测 Termux / Termux:API 是否安装及版本。
  static Future<TermuxStatus> checkInstalled() async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>('checkInstalled');
    return TermuxStatus.fromMap(map ?? <dynamic, dynamic>{});
  }

  /// 执行一条命令。[useTermux] 为 true 且 Termux 已安装时走 Termux，否则回退本地 shell。
  static Future<CommandResult> execute({
    required String command,
    String? sessionId,
    bool useTermux = true,
  }) async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>('execute', <String, dynamic>{
      'command': command,
      'sessionId': sessionId ?? '',
      'useTermux': useTermux,
    });
    return CommandResult.fromMap(map ?? <dynamic, dynamic>{});
  }

  /// 终止指定会话的本地进程。
  static Future<bool> kill(String sessionId) async {
    return await _channel.invokeMethod<bool>('kill', <String, dynamic>{'sessionId': sessionId}) ?? false;
  }

  /// 当前仍有本地进程在运行的会话 id 列表。
  static Future<List<String>> listSessions() async {
    final list = await _channel.invokeListMethod<String>('listSessions');
    return list ?? <String>[];
  }
}