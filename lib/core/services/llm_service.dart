import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_models.dart';

/// 内置模型服务商预设（均为 OpenAI 兼容协议）。
///
/// Anthropic / Google Gemini 采用各自独立协议，需专用 Adapter，
/// 尚未在本版接入（后续阶段实现，绝不伪造其兼容能力）。
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

/// LLM 服务：通过 OpenAI 兼容接口进行流式聊天。
///
/// 支持 DeepSeek / OpenAI / Kimi / 智谱 / 通义 / OpenRouter / Ollama / 自定义。
/// 采用 SSE 流式返回，逐段吐出增量文本。
class LlmService {
  const LlmService();

  /// 发起流式聊天请求，逐段产出 Token。
  Stream<String> streamChat({
    required ModelConfig model,
    required List<ChatMessage> messages,
  }) async* {
    if (model.requiresKey && model.apiKey.trim().isEmpty) {
      throw StateError('该模型尚未配置 API Key，请先在设置中填写');
    }

    final uri = _chatCompletionsUri(model.baseUrl);
    final request = http.Request('POST', uri)
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
        final delta = _parseDelta(data);
        if (delta.isNotEmpty) yield delta;
      }
    } finally {
      client.close();
    }
  }

  Uri _chatCompletionsUri(String baseUrl) {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/chat/completions');
  }

  /// 从 SSE `data:` 载荷中解析增量内容。
  static String _parseDelta(String data) {
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

  /// 尽量从错误响应中提取可读信息。
  static String _extractError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final err = json['error'];
      if (err is Map && err['message'] != null) return err['message'].toString();
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