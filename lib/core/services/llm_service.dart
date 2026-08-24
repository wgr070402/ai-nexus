import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_models.dart';

/// 内置模型服务商预设。
///
/// - OpenAI 兼容协议：DeepSeek / OpenAI / Kimi / 智谱 / 通义 / OpenRouter / Ollama；
/// - Anthropic Messages API：需专用 Adapter（`streamChat` 内按 provider 分派）；
/// - Google Gemini：需专用 Adapter（`streamChat` 内按 provider 分派）。
///
/// Anthropic / Gemini 采用各自独立协议，由 [LlmService] 分别实现流式解析，
/// 不再走 OpenAI 兼容通道，也不伪造其兼容能力。
class ModelRegistry {
  ModelRegistry._();

  static List<ModelConfig> defaults() => <ModelConfig>[
        const ModelConfig(
          id: 'deepseek',
          name: 'DeepSeek',
          provider: 'deepseek',
          baseUrl: 'https://api.deepseek.com/v1',
          model: 'deepseek-chat',
        ),
        const ModelConfig(
          id: 'openai',
          name: 'OpenAI',
          provider: 'openai',
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini',
        ),
        const ModelConfig(
          id: 'anthropic',
          name: 'Anthropic Claude',
          provider: 'anthropic',
          baseUrl: 'https://api.anthropic.com/v1',
          model: 'claude-3-5-haiku-latest',
        ),
        const ModelConfig(
          id: 'gemini',
          name: 'Google Gemini',
          provider: 'gemini',
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
          model: 'gemini-2.0-flash',
        ),
        const ModelConfig(
          id: 'moonshot',
          name: 'Kimi (Moonshot)',
          provider: 'moonshot',
          baseUrl: 'https://api.moonshot.cn/v1',
          model: 'moonshot-v1-8k',
        ),
        const ModelConfig(
          id: 'zhipu',
          name: '智谱 GLM',
          provider: 'zhipu',
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          model: 'glm-4-flash',
        ),
        const ModelConfig(
          id: 'qwen',
          name: '通义千问',
          provider: 'qwen',
          baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
          model: 'qwen-plus',
        ),
        const ModelConfig(
          id: 'openrouter',
          name: 'OpenRouter',
          provider: 'openrouter',
          baseUrl: 'https://openrouter.ai/api/v1',
          model: 'openai/gpt-4o-mini',
        ),
        const ModelConfig(
          id: 'ollama',
          name: 'Ollama (本地)',
          provider: 'ollama',
          baseUrl: 'http://localhost:11434/v1',
          model: 'llama3',
          requiresKey: false,
        ),
      ];
}

/// LLM 服务：流式聊天。
///
/// 依据 `model.provider` 分派到对应协议实现：
/// - `anthropic` → [LlmService._streamAnthropic]（Messages API，SSE 事件流）；
/// - `gemini`     → [LlmService._streamGemini]（streamGenerateContent，SSE）；
/// - 其余          → [LlmService._streamOpenAiCompatible]（chat/completions）。
class LlmService {
  const LlmService();

  /// Anthropic Messages API 要求每次请求显式指定 max_tokens，这里给一个宽裕默认值。
  static const int _anthropicMaxTokens = 4096;

  /// 发起流式聊天请求，逐段产出 Token。
  ///
  /// 按 [ModelConfig.provider] 选择协议；保证各协议流式增量文本均已正确解析。
  Stream<String> streamChat({
    required ModelConfig model,
    required List<ChatMessage> messages,
  }) async* {
    if (model.requiresKey && model.apiKey.trim().isEmpty) {
      throw StateError('该模型尚未配置 API Key，请先在设置中填写');
    }

    switch (model.provider) {
      case 'anthropic':
        yield* _streamAnthropic(model, messages);
      case 'gemini':
        yield* _streamGemini(model, messages);
      default:
        yield* _streamOpenAiCompatible(model, messages);
    }
  }

  // ---------- OpenAI 兼容 ----------

  Stream<String> _streamOpenAiCompatible(
    ModelConfig model,
    List<ChatMessage> messages,
  ) async* {
    final request = http.Request('POST', _endpoint(model.baseUrl, 'chat/completions'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(<String, dynamic>{
        'model': model.model,
        'stream': true,
        'messages': messages
            .where((m) => m.role != ChatRole.system || m.content.isNotEmpty)
            .map((m) => <String, dynamic>{
                  'role': m.role.apiName,
                  'content': m.content,
                })
            .toList(),
      });

    if (model.requiresKey && model.apiKey.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${model.apiKey.trim()}';
    }

    yield* _send(request, _parseOpenAiDelta);
  }

  /// 从 OpenAI 兼容 SSE `data:` 载荷中解析增量内容。
  static String _parseOpenAiDelta(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return '';
      final delta = (choices.first as Map<String, dynamic>)['delta'];
      final content = delta?['content'];
      return content?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  // ---------- Anthropic Messages API ----------

  Stream<String> _streamAnthropic(
    ModelConfig model,
    List<ChatMessage> messages,
  ) async* {
    // system 在 Anthropic 中是顶层字段，不进入 messages 数组。
    final system = messages
        .where((m) => m.role == ChatRole.system && m.content.isNotEmpty)
        .map((m) => m.content)
        .join('\n\n');
    final convo = messages
        .where((m) => m.role != ChatRole.system)
        .map((m) => <String, dynamic>{
              'role': m.role == ChatRole.assistant ? 'assistant' : 'user',
              'content': m.content,
            })
        .toList();

    final request = http.Request('POST', _endpoint(model.baseUrl, 'messages'))
      ..headers['Content-Type'] = 'application/json'
      ..headers['x-api-key'] = model.apiKey.trim()
      ..headers['anthropic-version'] = '2023-06-01'
      ..body = jsonEncode(<String, dynamic>{
        'model': model.model,
        'max_tokens': _anthropicMaxTokens,
        'stream': true,
        if (system.isNotEmpty) 'system': system,
        'messages': convo,
      });

    yield* _send(request, _parseAnthropicDelta);
  }

  /// 从 Anthropic SSE 事件中解析文本增量。
  ///
  /// 仅 `content_block_delta` 事件携带 `delta.type == "text_delta"` 时的 `delta.text`。
  static String _parseAnthropicDelta(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      if (json['type'] != 'content_block_delta') return '';
      final delta = json['delta'];
      if (delta is Map && delta['type'] == 'text_delta') {
        return delta['text']?.toString() ?? '';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  // ---------- Google Gemini API ----------

  Stream<String> _streamGemini(
    ModelConfig model,
    List<ChatMessage> messages,
  ) async* {
    // system 在 Gemini 中通过顶层 systemInstruction 表达，角色只能是 user / model。
    final system = messages
        .where((m) => m.role == ChatRole.system && m.content.isNotEmpty)
        .map((m) => m.content)
        .join('\n\n');
    final contents = messages
        .where((m) => m.role != ChatRole.system)
        .map((m) => <String, dynamic>{
              'role': m.role == ChatRole.assistant ? 'model' : 'user',
              'parts': <dynamic>[
                <String, dynamic>{'text': m.content},
              ],
            })
        .toList();

    final request = http.Request('POST', _geminiUri(model))
      ..headers['Content-Type'] = 'application/json'
      ..headers['x-goog-api-key'] = model.apiKey.trim()
      ..body = jsonEncode(<String, dynamic>{
        'contents': contents,
        if (system.isNotEmpty)
          'systemInstruction': <String, dynamic>{
            'parts': <dynamic>[
              <String, dynamic>{'text': system},
            ],
          },
      });

    yield* _send(request, _parseGeminiDelta);
  }

  Uri _geminiUri(ModelConfig model) {
    final base = model.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final modelPart = Uri.encodeComponent(model.model);
    return Uri.parse('$base/models/$modelPart:streamGenerateContent?alt=sse');
  }

  /// 从 Gemini SSE 增量中解析文本。
  ///
  /// 每个 `data:` 载荷含 `candidates[0].content.parts[*].text`，拼接全部文本片段。
  static String _parseGeminiDelta(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return '';
      final content =
          (candidates.first as Map<String, dynamic>)['content'];
      final parts = content is Map ? content['parts'] as List<dynamic>? : null;
      if (parts == null) return '';
      final buf = StringBuffer();
      for (final p in parts) {
        final text = p is Map ? p['text']?.toString() : null;
        if (text != null && text.isNotEmpty) buf.write(text);
      }
      return buf.toString();
    } catch (_) {
      return '';
    }
  }

  // ---------- 公共传输 ----------

  /// 发送流式请求并按行解析 SSE `data:` 载荷，交给 [parseDelta] 产出文本增量。
  Stream<String> _send(
    http.Request request,
    String Function(String data) parseDelta,
  ) async* {
    final client = http.Client();
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 400) {
        final body = await response.stream.bytesToString();
        throw HttpException(
          '请求失败 HTTP ${response.statusCode}: ${_extractError(body)}',
        );
      }

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty || !line.startsWith('data:')) continue;
        final data = line.substring('data:'.length).trim();
        if (data == '[DONE]') break;
        final delta = parseDelta(data);
        if (delta.isNotEmpty) yield delta;
      }
    } finally {
      client.close();
    }
  }

  /// 依据 baseUrl 拼接相对路径，得到完整端点。
  Uri _endpoint(String baseUrl, String path) {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/$path');
  }

  /// 尽量从错误响应中提取可读信息。
  static String _extractError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final err = json['error'];
      if (err is Map && err['message'] != null) return err['message'].toString();
      if (err is String && err.isNotEmpty) return err;
      return body;
    } catch (_) {
      return body;
    }
  }
}

/// 面向业务层的轻量 HTTP 异常。
class HttpException implements Exception {
  const HttpException(this.message);

  final String message;

  @override
  String toString() => message;
}