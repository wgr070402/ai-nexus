import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';
import 'llm_service.dart';

/// 本地持久化层：
/// - 模型配置（不含密钥）存 SharedPreferences；
/// - API Key 存 Android Keystore（flutter_secure_storage），绝不落明文；
/// - 会话与消息存 SharedPreferences（JSON）。
class AppStorage {
  AppStorage._();

  static const String _kModels = 'model_configs';
  static const String _kActiveModel = 'active_model_id';
  static const String _kSessions = 'chat_sessions';
  static const String _kActiveSession = 'active_session_id';

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  // ---------- 模型配置 ----------

  /// 读取模型列表（含从安全存储注入的 API Key）。
  static Future<List<ModelConfig>> loadModels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kModels);

    List<ModelConfig> models;
    if (raw == null || raw.isEmpty) {
      models = ModelRegistry.defaults();
      await _saveModelsRaw(prefs, models);
    } else {
      try {
        final list = (jsonDecode(raw) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(ModelConfig.fromJson)
            .toList();
        models = list.isEmpty ? ModelRegistry.defaults() : list;
      } catch (_) {
        models = ModelRegistry.defaults();
      }
    }

    // 注入 API Key
    return Future.wait(models.map(_withKey));
  }

  static Future<ModelConfig> _withKey(ModelConfig model) async {
    final key = await _secure.read(key: 'model_key_${model.id}') ?? '';
    return model.copyWith(apiKey: key);
  }

  /// 保存单个模型配置（含 API Key 落安全存储）。
  static Future<void> saveModel(ModelConfig model) async {
    if (model.requiresKey && model.apiKey.trim().isNotEmpty) {
      await _secure.write(key: 'model_key_${model.id}', value: model.apiKey.trim());
    }
    final prefs = await SharedPreferences.getInstance();
    final models = (await loadModels()).map((m) {
      return m.id == model.id ? model.copyWith(apiKey: '') : m;
    }).toList();
    // 若为新模型则追加
    if (!models.any((m) => m.id == model.id)) {
      models.add(model.copyWith(apiKey: ''));
    }
    await _saveModelsRaw(prefs, models);
  }

  static Future<void> _saveModelsRaw(
      SharedPreferences prefs, List<ModelConfig> models) async {
    final list = models
        .map((m) => m.copyWith(apiKey: '').toJson())
        .toList();
    await prefs.setString(_kModels, jsonEncode(list));
  }

  /// 删除某个模型配置（同时清除其安全存储中的 API Key）。
  static Future<void> deleteModel(String id) async {
    await _secure.delete(key: 'model_key_$id');
    final prefs = await SharedPreferences.getInstance();
    final models = (await loadModels()).where((m) => m.id != id).toList();
    await _saveModelsRaw(prefs, models);
  }

  /// 仅清除某个模型的 API Key（保留配置）。
  static Future<void> clearApiKey(String id) async {
    await _secure.delete(key: 'model_key_$id');
  }

  // ---------- 会话 ----------

  static Future<List<ChatSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSessions);
    if (raw == null || raw.isEmpty) return <ChatSession>[];
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ChatSession.fromJson)
          .toList();
      return list;
    } catch (_) {
      return <ChatSession>[];
    }
  }

  static Future<void> saveSessions(List<ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final list = sessions.map((s) => s.toJson()).toList();
    await prefs.setString(_kSessions, jsonEncode(list));
  }

  // ---------- 当前选中项 ----------

  static Future<String?> activeModelId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveModel);
  }

  static Future<void> setActiveModelId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveModel, id);
  }

  static Future<String?> activeSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveSession);
  }

  static Future<void> setActiveSessionId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveSession, id);
  }
}