import 'package:flutter/services.dart';

import 'termux_bridge.dart' show CommandResult;

/// PRoot 内置 Ubuntu 就绪状态与下载进度。
class ProotStatus {
  const ProotStatus({
    required this.prootBinary,
    required this.installed,
    required this.downloading,
    required this.phase,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.error,
    required this.rootfsPath,
    required this.arch,
  });

  /// 内置 PRoot 二进制是否就位（jniLibs/arm64-v8a 或已复制到私有目录）。
  final bool prootBinary;

  /// rootfs 是否已解压完成。
  final bool installed;

  /// 是否正在下载/解压 rootfs。
  final bool downloading;

  /// 当前阶段：prepare / download / extract / done。
  final String phase;

  final int downloadedBytes;
  final int totalBytes;
  final String error;
  final String rootfsPath;
  final String arch;

  /// 整体就绪（可执行 Linux 命令）。
  bool get ready => prootBinary && installed;

  /// 下载进度 0~1；totalBytes 未知时返回 -1。
  double get progress {
    if (totalBytes <= 0) return -1;
    if (downloadedBytes <= 0) return 0;
    final p = downloadedBytes / totalBytes;
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }

  factory ProotStatus.fromMap(Map<dynamic, dynamic> map) => ProotStatus(
        prootBinary: map['prootBinary'] == true,
        installed: map['installed'] == true,
        downloading: map['downloading'] == true,
        phase: map['phase']?.toString() ?? '',
        downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
        totalBytes: (map['totalBytes'] as num?)?.toInt() ?? -1,
        error: map['error']?.toString() ?? '',
        rootfsPath: map['rootfsPath']?.toString() ?? '',
        arch: map['arch']?.toString() ?? '',
      );
}

/// PRoot 内置 Ubuntu 桥接层：与原生 ProotBridge 通信。
///
/// MethodChannel 名约定为 `com.ai-nexus/proot`。相比 Termux，PRoot 方案
/// 无需安装任何第三方 App，首次运行时自动下载 rootfs，规避后台杀进程问题。
class ProotBridge {
  const ProotBridge._();

  static const MethodChannel _channel = MethodChannel('com.ai-nexus/proot');

  /// 查询 PRoot 二进制 / rootfs 就绪状态与下载进度。
  static Future<ProotStatus> status() async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>('status');
    return ProotStatus.fromMap(map ?? <dynamic, dynamic>{});
  }

  /// 触发 rootfs 下载与解压（幂等；已在安装则立即返回 installed）。
  static Future<bool> install() async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>('install');
    return map?['started'] == true;
  }

  /// 在 PRoot Ubuntu 内执行命令，返回结构化结果。
  static Future<CommandResult> execute({
    required String command,
    String? sessionId,
  }) async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>('execute',
        <String, dynamic>{'command': command, 'sessionId': sessionId ?? ''});
    return CommandResult.fromMap(map ?? <dynamic, dynamic>{});
  }

  /// 终止指定会话的进程。
  static Future<bool> cancel(String sessionId) async {
    return await _channel
            .invokeMethod<bool>('cancel', <String, dynamic>{'sessionId': sessionId}) ??
        false;
  }
}