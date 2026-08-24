import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/skill_models.dart';

/// 技能库控制器：技能 CRUD + 启停 + 持久化。
class SkillController extends ChangeNotifier {
  static const String _kSkills = 'skills';

  List<Skill> _skills = <Skill>[];
  List<Skill> get skills => List.unmodifiable(_skills);

  Future<void> init() async {
    _skills = await _load();
    dev.log('初始化：载入技能数=${_skills.length}', name: 'Skill');
    notifyListeners();
  }

  Future<List<Skill>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSkills);
    if (raw == null || raw.isEmpty) return <Skill>[];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Skill.fromJson)
          .toList();
    } catch (e) {
      dev.log('读取技能失败，忽略：$e', name: 'Skill', error: e);
      return <Skill>[];
    }
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _skills.map((s) => s.toJson()).toList();
    dev.log('持久化技能数=${list.length}', name: 'Skill');
    await prefs.setString(_kSkills, jsonEncode(list));
  }

  Future<void> save(Skill skill) async {
    final index = _skills.indexWhere((s) => s.id == skill.id);
    if (index < 0) {
      _skills.add(skill);
    } else {
      _skills[index] = skill;
    }
    dev.log('保存技能 id=${skill.id} name=${skill.name} enabled=${skill.enabled}',
        name: 'Skill');
    notifyListeners();
    await persist();
  }

  Future<void> delete(String id) async {
    _skills.removeWhere((s) => s.id == id);
    dev.log('删除技能 id=$id 剩余=${_skills.length}', name: 'Skill');
    notifyListeners();
    await persist();
  }

  Future<void> toggleEnabled(String id) async {
    final index = _skills.indexWhere((s) => s.id == id);
    if (index < 0) return;
    _skills[index].enabled = !_skills[index].enabled;
    dev.log('切换技能 id=$id enabled=${_skills[index].enabled}', name: 'Skill');
    notifyListeners();
    await persist();
  }
}