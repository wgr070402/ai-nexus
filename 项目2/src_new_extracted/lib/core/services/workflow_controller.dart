import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workflow_models.dart';

/// 工作流控制器：加载、创建、更新、删除与持久化。
class WorkflowController extends ChangeNotifier {
  static const String _kWorkflows = 'workflows';

  List<Workflow> _workflows = <Workflow>[];
  List<Workflow> get workflows => List.unmodifiable(_workflows);

  Future<void> init() async {
    _workflows = await _load();
    notifyListeners();
  }

  Future<List<Workflow>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kWorkflows);
    if (raw == null || raw.isEmpty) return <Workflow>[];
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Workflow.fromJson)
          .toList();
      return list;
    } catch (_) {
      return <Workflow>[];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _workflows.map((w) => w.toJson()).toList();
    await prefs.setString(_kWorkflows, jsonEncode(list));
  }

  Future<void> save(Workflow workflow) async {
    final index = _workflows.indexWhere((w) => w.id == workflow.id);
    if (index < 0) {
      _workflows.add(workflow);
    } else {
      _workflows[index] = workflow;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _workflows.removeWhere((w) => w.id == id);
    await _persist();
    notifyListeners();
  }
}