import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/group_models.dart';

/// 群聊（Multi-Agent）控制器：负责群会话的加载、创建、删除与持久化。
///
/// 群聊消息直接写入 [GroupSession.messages]，由调用方在流式完成后调用
/// [persist] 落盘；[refresh] 用于驱动 UI 刷新。
class GroupController extends ChangeNotifier {
  static const String _kGroups = 'group_sessions';

  List<GroupSession> _sessions = <GroupSession>[];
  List<GroupSession> get sessions => List.unmodifiable(_sessions);

  Future<void> init() async {
    _sessions = await _load();
    notifyListeners();
  }

  Future<List<GroupSession>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kGroups);
    if (raw == null || raw.isEmpty) return <GroupSession>[];
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(GroupSession.fromJson)
          .toList();
      return list;
    } catch (_) {
      return <GroupSession>[];
    }
  }

  /// 将全部群会话落盘。
  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _sessions.map((s) => s.toJson()).toList();
    await prefs.setString(_kGroups, jsonEncode(list));
  }

  /// 新建群聊会话。
  Future<GroupSession> createGroup(String title, List<String> agentIds) async {
    final session = GroupSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? '未命名群聊' : title.trim(),
      agentIds: agentIds,
    );
    _sessions.insert(0, session);
    await persist();
    notifyListeners();
    return session;
  }

  /// 删除指定群聊。
  Future<void> deleteGroup(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    await persist();
    notifyListeners();
  }

  /// 消息内容变更后驱动 UI 刷新（等价 notifyListeners）。
  void refresh() => notifyListeners();
}