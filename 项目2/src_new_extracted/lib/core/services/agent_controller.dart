import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/agent_models.dart';

/// Agent 控制器：负责 Agent 的加载、增删改查与持久化。
class AgentController extends ChangeNotifier {
  static const String _kAgents = 'agents';

  List<Agent> _agents = <Agent>[];
  List<Agent> get agents => _agents;

  Future<void> init() async {
    _agents = await _load();
    notifyListeners();
  }

  Future<List<Agent>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAgents);
    if (raw == null || raw.isEmpty) return <Agent>[];
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Agent.fromJson)
          .toList();
      return list;
    } catch (_) {
      return <Agent>[];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _agents.map((a) => a.toJson()).toList();
    await prefs.setString(_kAgents, jsonEncode(list));
  }

  /// 新建 Agent（id 由调用方或此方法自动生成）。
  Future<Agent> addAgent(Agent agent) async {
    _agents.add(agent);
    await _persist();
    notifyListeners();
    return agent;
  }

  /// 更新已有 Agent（按 id 匹配）。
  Future<void> updateAgent(Agent agent) async {
    final index = _agents.indexWhere((a) => a.id == agent.id);
    if (index < 0) {
      _agents.add(agent);
    } else {
      _agents[index] = agent;
    }
    await _persist();
    notifyListeners();
  }

  /// 删除指定 id 的 Agent。
  Future<void> deleteAgent(String id) async {
    _agents.removeWhere((a) => a.id == id);
    await _persist();
    notifyListeners();
  }

  /// 切换启用状态。
  Future<void> toggleEnabled(String id) async {
    final index = _agents.indexWhere((a) => a.id == id);
    if (index < 0) return;
    _agents[index].enabled = !_agents[index].enabled;
    _agents[index].updatedAt = DateTime.now();
    await _persist();
    notifyListeners();
  }
}