import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/knowledge_models.dart';

/// 知识库控制器：文档 CRUD + 搜索 + 持久化。
class KnowledgeController extends ChangeNotifier {
  static const String _kDocs = 'knowledge_docs';

  List<KnowledgeDoc> _docs = <KnowledgeDoc>[];
  List<KnowledgeDoc> get docs => List.unmodifiable(_docs);

  Future<void> init() async {
    _docs = await _load();
    dev.log('初始化：载入文档数=${_docs.length}', name: 'Knowledge');
    notifyListeners();
  }

  Future<List<KnowledgeDoc>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDocs);
    if (raw == null || raw.isEmpty) return <KnowledgeDoc>[];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(KnowledgeDoc.fromJson)
          .toList();
    } catch (e) {
      dev.log('读取知识库失败，忽略：$e', name: 'Knowledge', error: e);
      return <KnowledgeDoc>[];
    }
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _docs.map((d) => d.toJson()).toList();
    dev.log('持久化文档数=${list.length}', name: 'Knowledge');
    await prefs.setString(_kDocs, jsonEncode(list));
  }

  Future<void> save(KnowledgeDoc doc) async {
    final index = _docs.indexWhere((d) => d.id == doc.id);
    if (index < 0) {
      _docs.insert(0, doc);
    } else {
      _docs[index] = doc;
    }
    dev.log('保存文档 id=${doc.id} title=${doc.title} content=${doc.content.length}字符',
        name: 'Knowledge');
    notifyListeners();
    await persist();
  }

  Future<void> delete(String id) async {
    _docs.removeWhere((d) => d.id == id);
    dev.log('删除文档 id=$id 剩余=${_docs.length}', name: 'Knowledge');
    notifyListeners();
    await persist();
  }

  /// 按关键词 / 分类简单搜索（标题 + 内容 + 标签）。
  List<KnowledgeDoc> search(String keyword) {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return docs;
    return _docs.where((d) {
      final hay = '${d.title} ${d.content} ${d.category} ${d.tags.join(' ')}'
          .toLowerCase();
      return hay.contains(k);
    }).toList();
  }
}