/// 模型配置（对应「模型与引擎」里的本地/云端模型供应商配置）
class ModelConfig {
  const ModelConfig({
    required this.id,
    required this.provider,
    required this.apiKey,
    required this.baseUrl,
    required this.modelName,
    this.isLocal = false,
  });

  final String id;
  final String provider; // deepseek / openai / anthropic / gemini / kimi / zhipu / qwen / openrouter / ollama
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final bool isLocal; // 本地模型（Ollama）

  ModelConfig copyWith({
    String? id,
    String? provider,
    String? apiKey,
    String? baseUrl,
    String? modelName,
    bool? isLocal,
  }) {
    return ModelConfig(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider,
        'apiKey': apiKey,
        'baseUrl': baseUrl,
        'modelName': modelName,
        'isLocal': isLocal,
      };

  factory ModelConfig.fromJson(Map<String, dynamic> json) => ModelConfig(
        id: json['id'] as String,
        provider: json['provider'] as String,
        apiKey: json['apiKey'] as String,
        baseUrl: json['baseUrl'] as String,
        modelName: json['modelName'] as String,
        isLocal: json['isLocal'] as bool? ?? false,
      );
}

/// 内置供应商预设（文档第 8 章「本地/云端模型」）
const Map<String, String> kProviderBaseUrls = {
  'deepseek': 'https://api.deepseek.com/v1',
  'openai': 'https://api.openai.com/v1',
  'anthropic': 'https://api.anthropic.com/v1',
  'gemini': 'https://generativelanguage.googleapis.com/v1beta',
  'kimi': 'https://api.moonshot.cn/v1',
  'zhipu': 'https://open.bigmodel.cn/api/paas/v4',
  'qwen': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  'openrouter': 'https://openrouter.ai/api/v1',
  'ollama': 'http://127.0.0.1:11434/v1',
};
