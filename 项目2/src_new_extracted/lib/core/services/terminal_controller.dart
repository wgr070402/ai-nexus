import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/terminal_models.dart';

/// 终端会话控制器：管理多会话、切换、增删与持久化。
///
/// 会话内的命令/历史由页面直接写入 [TermSession.commands] / [TermSession.history]，
/// 再由页面调用 [refresh] 驱动 UI 刷新、[persist] 落盘。
class TerminalController extends ChangeNotifier {
  static const String _kSessions = 'term_sessions';

  List<TermSession> _sessions = <TermSession>[];
  String? _activeId;

  List<TermSession> get sessions => List.unmodifiable(_sessions);
  String? get activeId => _activeId;

  TermSession? get active {
    for (final s in _sessions) {
      if (s.id == _activeId) return s;
    }
    return _sessions.isEmpty ? null : _sessions.first;
  }

  Future<void> init() async {
    _sessions = await _load();
    dev.log('初始化：载入会话数=${_sessions.length}', name: 'TerminalSession');
    if (_sessions.isEmpty) {
      _sessions.add(_newSession(1));
      dev.log('无历史会话，创建默认会话「会话 1」', name: 'TerminalSession');
      await persist();
    }
    _activeId = _sessions.first.id;
    dev.log('激活会话 id=$_activeId name=${active?.name}', name: 'TerminalSession');
    notifyListeners();
  }

  Future<List<TermSession>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSessions);
    if (raw == null || raw.isEmpty) return <TermSession>[];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(TermSession.fromJson)
          .toList();
    } catch (e) {
      dev.log('读取会话失败，忽略：$e', name: 'TerminalSession', error: e);
      return <TermSession>[];
    }
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _sessions.map((s) => s.toJson()).toList();
    dev.log('持久化会话数=${list.length}', name: 'TerminalSession');
    await prefs.setString(_kSessions, jsonEncode(list));
  }

  TermSession _newSession(int index) => TermSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: '会话 $index',
      );

  /// 新建会话并切换为当前。
  TermSession createSession() {
    final session = _newSession(_sessions.length + 1);
    _sessions.insert(0, session);
    _activeId = session.id;
    dev.log('新建会话 id=${session.id} name=${session.name}', name: 'TerminalSession');
    notifyListeners();
    persist();
    return session;
  }

  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    dev.log('删除会话 id=$id 剩余=${_sessions.length}', name: 'TerminalSession');
    if (_activeId == id) {
      _activeId = _sessions.isEmpty ? null : _sessions.first.id;
    }
    if (_sessions.isEmpty) {
      _sessions.add(_newSession(1));
      _activeId = _sessions.first.id;
      dev.log('全部会话被删，自动补建默认会话', name: 'TerminalSession');
    }
    notifyListeners();
    await persist();
  }

  void switchSession(String id) {
    if (_activeId == id) return;
    _activeId = id;
    dev.log('切换会话 id=$id name=${active?.name}', name: 'TerminalSession');
    notifyListeners();
  }

  void refresh() => notifyListeners();
}