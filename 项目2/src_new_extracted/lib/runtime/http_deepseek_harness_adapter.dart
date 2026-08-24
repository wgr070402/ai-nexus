import 'dart:convert';
import 'dart:io';

import 'deepseek_harness_adapter.dart';
import 'runtime_result.dart';

/// DeepSeek Harness 的 HTTP 传输实现。
///
/// 通过 HTTP JSON 与独立的 DeepSeek Harness 服务通信（本地或远程）。
/// 未配置 / 不可达时，所有方法均返回明确的失败信息，绝不伪造执行结果。
class HttpDeepSeekHarnessAdapter implements DeepSeekHarnessAdapter {
  HttpDeepSeekHarnessAdapter({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 8),
  }) : assert(baseUrl.trim().isNotEmpty);

  /// Harness 服务地址，例如 `http://127.0.0.1:8765`。
  final String baseUrl;

  /// 单次请求超时。
  final Duration timeout;

  /// 本地支持的 Harness API 版本号，必须与后端一致才会判定为兼容。
  static const int supportedApiVersion = 1;

  final HttpClient _client = HttpClient();

  @override
  Future<HarnessDetectResult> detect() async {
    try {
      final raw = await _request('GET', '/detect');
      final body = jsonDecode(raw) as Map<String, dynamic>;
      if (body['available'] != true) {
        return HarnessDetectResult.unavailable('DeepSeek Harness 不可用');
      }
      final serverVersion = (body['apiVersion'] as num?)?.toInt() ?? -1;
      if (serverVersion != supportedApiVersion) {
        return HarnessDetectResult(
          available: true,
          version: '$serverVersion',
          compatible: false,
          message: '版本不兼容：本地支持 v$supportedApiVersion，服务端为 v$serverVersion',
        );
      }
      return HarnessDetectResult(
        available: true,
        version: '$serverVersion',
        compatible: true,
      );
    } catch (e) {
      return HarnessDetectResult.unavailable('DeepSeek Harness 未连接：$e');
    }
  }

  @override
  Future<HarnessSession> connect({required String apiKey, required String workspace}) async {
    final body = await _post('/connect', <String, dynamic>{
      'apiKey': apiKey,
      'workspace': workspace,
    });
    final sessionId = body['sessionId']?.toString() ?? '';
    if (sessionId.isEmpty) {
      throw StateError('DeepSeek Harness 连接失败：未返回 sessionId');
    }
    return HarnessSession(sessionId: sessionId, workspace: workspace);
  }

  @override
  Future<RuntimeResult> run({
    required String sessionId,
    required String code,
    required String language,
  }) async {
    final body = await _post('/run', <String, dynamic>{
      'sessionId': sessionId,
      'code': code,
      'language': language,
    });
    return RuntimeResult.fromMap(body);
  }

  @override
  Future<RuntimeResult> test({
    required String sessionId,
    required String testCommand,
  }) async {
    final body = await _post('/test', <String, dynamic>{
      'sessionId': sessionId,
      'testCommand': testCommand,
    });
    return RuntimeResult.fromMap(body);
  }

  @override
  Future<bool> cancel(String sessionId) async {
    final body = await _post('/cancel', <String, dynamic>{'sessionId': sessionId});
    return body['ok'] == true;
  }

  @override
  Future<bool> disconnect(String sessionId) async {
    final body = await _post('/disconnect', <String, dynamic>{'sessionId': sessionId});
    return body['ok'] == true;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> payload) async {
    final raw = await _request('POST', path, body: payload);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<String> _request(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await _client.openUrl(method, uri).timeout(timeout);
    request.headers.contentType = ContentType.json;
    if (body != null) {
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(timeout);
    final text = await response.transform(utf8.decoder).join().timeout(timeout);
    if (response.statusCode >= 400) {
      throw HttpException('HTTP ${response.statusCode}: $text', uri: uri);
    }
    return text;
  }
}