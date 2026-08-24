import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'codex_adapter.dart';

/// Codex 的 HTTP 实现，对接 OpenAI Responses API。
///
/// - [detect] 通过 `GET /models` 校验 API Key 与连通性；
/// - [generate] 通过 `POST /responses` 生成代码。
///
/// 未配置 Key / 网络不可达 / 服务端报错时，均返回明确失败信息，绝不伪造结果。
class HttpCodexAdapter implements CodexAdapter {
  HttpCodexAdapter({
    this.baseUrl = 'https://api.openai.com/v1',
    this.timeout = const Duration(seconds: 30),
  });

  /// 服务端点（默认 OpenAI 官方）。
  final String baseUrl;

  /// 单次请求超时。
  final Duration timeout;

  final HttpClient _client = HttpClient();

  @override
  Future<CodexDetectResult> detect({required String apiKey}) async {
    if (apiKey.trim().isEmpty) {
      dev.log('detect：未配置 API Key', name: 'CodexAdapter');
      return const CodexDetectResult(available: false, message: '未配置 API Key');
    }
    try {
      await _request('GET', '/models', apiKey: apiKey);
      dev.log('detect：连通性与鉴权校验通过', name: 'CodexAdapter');
      return const CodexDetectResult(available: true);
    } catch (e) {
      dev.log('detect 失败：$e', name: 'CodexAdapter', error: e);
      return CodexDetectResult(available: false, message: '连接失败：$e');
    }
  }

  @override
  Future<CodexGenerateResult> generate({
    required String apiKey,
    required String model,
    required String prompt,
    List<CodexMessage> history = const <CodexMessage>[],
  }) async {
    if (apiKey.trim().isEmpty) {
      return CodexGenerateResult.failure('未配置 API Key');
    }
    if (prompt.trim().isEmpty) {
      return CodexGenerateResult.failure('任务描述不能为空');
    }

    final payload = <String, dynamic>{
      'model': model,
      'instructions': 'You are OpenAI Codex, an expert coding assistant. '
          'Output clean, complete, runnable code with minimal explanation.',
    };
    if (history.isNotEmpty) {
      payload['input'] = <Map<String, dynamic>>[
        for (final m in history)
          <String, dynamic>{'role': m.role, 'content': m.content},
        <String, dynamic>{'role': 'user', 'content': prompt},
      ];
    } else {
      payload['input'] = prompt;
    }

    dev.log(
      'generate：model=$model prompt=${prompt.length}字符 history=${history.length}',
      name: 'CodexAdapter',
    );
    try {
      final body = await _post('/responses', payload, apiKey: apiKey);
      final output = _extractOutput(body);
      final usedModel = body['model']?.toString() ?? model;
      dev.log('generate：成功 model=$usedModel output=${output.length}字符',
          name: 'CodexAdapter');
      return CodexGenerateResult(
        success: true,
        output: output,
        model: usedModel,
      );
    } catch (e) {
      dev.log('generate 失败：$e', name: 'CodexAdapter', error: e);
      return CodexGenerateResult.failure(e.toString());
    }
  }

  /// 从 Responses API 返回体中抽取文本输出。
  String _extractOutput(Map<String, dynamic> body) {
    final output = body['output'];
    if (output is! List) return '';
    final buffer = StringBuffer();
    for (final item in output) {
      if (item is! Map<String, dynamic> || item['type'] != 'message') {
        continue;
      }
      final content = item['content'];
      if (content is! List) continue;
      for (final c in content) {
        if (c is Map<String, dynamic> && c['type'] == 'output_text') {
          buffer.writeln(c['text']?.toString() ?? '');
        }
      }
    }
    return buffer.toString().trim();
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload, {
    required String apiKey,
  }) async {
    final raw = await _request('POST', path, apiKey: apiKey, body: payload);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<String> _request(
    String method,
    String path, {
    required String apiKey,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await _client.openUrl(method, uri).timeout(timeout);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    if (body != null) {
      request.headers.contentType = ContentType.json;
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