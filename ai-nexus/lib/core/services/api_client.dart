import 'package:dio/dio.dart';
import '../models/model_config.dart';

/// 统一 HTTP 客户端（dio），提供流式与非流式请求
class ApiClient {
  ApiClient() : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));

  final Dio _dio;

  /// 非流式 POST（用于测试连接等）
  Future<Response<T>> post<T>(
    ModelConfig cfg,
    String path, {
    Map<String, dynamic>? body,
    CancelToken? cancelToken,
  }) {
    final url = '${cfg.baseUrl}$path';
    return _dio.post<T>(
      url,
      data: body,
      cancelToken: cancelToken,
      options: Options(
        headers: {'Authorization': 'Bearer ${cfg.apiKey}'},
      ),
    );
  }

  /// 流式 POST（SSE），返回逐行数据流
  Future<Response<ResponseBody>> postStream(
    ModelConfig cfg,
    String path, {
    required Map<String, dynamic> body,
    CancelToken? cancelToken,
  }) {
    final url = '${cfg.baseUrl}$path';
    return _dio.post<ResponseBody>(
      url,
      data: body,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Authorization': 'Bearer ${cfg.apiKey}'},
      ),
    );
  }
}
