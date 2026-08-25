import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/chat_models.dart';
import '../models/model_config.dart';
import 'api_client.dart';

/// 流式聊天服务（OpenAI 兼容 / SSE）
/// 支持取消（流式中切模型 = cancel + 重答）
class ChatService {
  ChatService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// 发起流式聊天，返回增量文本流。
  /// [cancelToken] 用于「流式中切模型」：取消即中断当前流。
  Stream<StreamChunk> chat({
    required ModelConfig cfg,
    required List<ChatMessage> messages,
    CancelToken? cancelToken,
  }) {
    final body = <String, dynamic>{
      'model': cfg.modelName,
      'stream': true,
      'messages': messages
          .map((m) => {'role': m.role.name, 'content': m.content})
          .toList(),
    };

    final controller = StreamController<StreamChunk>();
    final buffer = StringBuffer();

    _client
        .postStream(cfg, '/chat/completions',
            body: body, cancelToken: cancelToken)
        .then((response) {
      final stream = response.data!.stream;
      stream.listen(
        (chunk) => _handleChunk(buffer, utf8.decode(chunk), controller),
        onError: (Object e) {
          if (!controller.isClosed) controller.addError(e);
        },
        onDone: () {
          // 处理剩余缓冲
          final rest = buffer.toString().trim();
          if (rest.isNotEmpty) _parseLine(rest, controller);
          if (!controller.isClosed) {
            controller.add(const StreamChunk(delta: '', isDone: true));
            controller.close();
          }
        },
        cancelOnError: true,
      );
    }).catchError((Object e) {
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    });

    return controller.stream;
  }

  /// 处理一段 chunk：按行分割，保留最后一个不完整行
  void _handleChunk(
      StringBuffer buffer, String text, StreamController<StreamChunk> c) {
    buffer.write(text);
    final lines = buffer.toString().split('\n');
    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) _parseLine(line, c);
    }
    buffer
      ..clear()
      ..write(lines.last);
  }

  /// 解析单行 SSE：`data: {...}` 或 `data: [DONE]`
  void _parseLine(String line, StreamController<StreamChunk> c) {
    if (!line.startsWith('data:')) return;
    final data = line.substring(5).trim();
    if (data == '[DONE]') {
      c.add(const StreamChunk(delta: '', isDone: true));
      return;
    }
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return;
      final delta = choices.first['delta'] as Map<String, dynamic>?;
      final content = delta?['content'] as String?;
      if (content != null && content.isNotEmpty) {
        c.add(StreamChunk(delta: content));
      }
    } catch (_) {
      // 忽略无法解析的行
    }
  }
}
