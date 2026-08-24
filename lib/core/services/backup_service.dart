import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_service.dart';

/// 数据备份与恢复服务。
///
/// 将全部功能模块的数据（模型 / Agent / 技能 / 工作流 / 知识库 / 群聊 /
/// 单聊 / 终端）从 SharedPreferences 统一导出为 JSON，并可打包为 zip；
/// 导入时按 key 逐项覆盖写回，导入前由页面进行二次确认。
///
/// 安全说明：API Key 存于系统安全存储（Android Keystore），【不】随备份
/// 导出，避免敏感信息泄漏。
class BackupService {
  BackupService._();

  static const String _tag = 'BackupService';

  /// 备份格式版本号，便于未来迭代兼容。
  static const int formatVersion = 1;

  /// 允许备份 / 恢复的数据 key（白名单，避免误写其它内部 key）。
  static const List<String> dataKeys = <String>[
    'model_configs', // 模型配置
    'active_model_id', // 默认模型
    'chat_sessions', // 单聊会话
    'active_session_id', // 当前会话
    'agents', // Agent
    'skills', // 技能
    'workflows', // 工作流
    'knowledge_docs', // 知识库
    'group_sessions', // 群聊
    'term_sessions', // 终端会话
  ];

  /// 收集当前所有数据，返回 key -> 原始 JSON 字符串。
  static Future<Map<String, dynamic>> collect() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in dataKeys) {
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) {
        data[key] = value;
      }
    }
    dev.log('收集数据 keyCount=${data.length}', name: _tag);
    return data;
  }

  /// 生成完整备份 JSON。
  static Future<String> toJson() async {
    final data = await collect();
    final payload = <String, dynamic>{
      'app': 'ai_nexus',
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    };
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    dev.log('导出备份 JSON bytes=${utf8.encode(json).length}', name: _tag);
    return json;
  }

  /// 将备份 JSON 打包为 zip，写入应用文档目录，返回输出文件路径。
  static Future<File> toZip(String json) async {
    final bytes = utf8.encode(json);
    final archive = Archive()
      ..addFile(ArchiveFile('ai_nexus_backup.json', bytes.length, bytes));
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('zip 编码失败');
    }
    final docs = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final out = File(
        '${docs.path}${Platform.pathSeparator}ai_nexus_backup_$stamp.zip');
    await out.writeAsBytes(zipBytes, flush: true);
    dev.log('导出备份 zip path=${out.path} size=${zipBytes.length}', name: _tag);
    return out;
  }

  /// 校验并恢复备份 JSON，返回成功写入的 key 数量。
  static Future<int> restore(String json) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份格式无效：顶层应为对象');
    }
    final dataRaw = decoded['data'];
    if (dataRaw is! Map<String, dynamic> || dataRaw.isEmpty) {
      throw const FormatException('备份内容为空或缺少 data 字段');
    }
    final prefs = await SharedPreferences.getInstance();
    int count = 0;
    for (final key in dataKeys) {
      final value = dataRaw[key];
      if (value == null) continue;
      await prefs.setString(key, value.toString());
      count++;
    }
    dev.log('恢复备份 keyCount=$count', name: _tag);
    return count;
  }

  /// 从 zip 字节中解析出备份 JSON 并恢复。
  static Future<int> restoreZip(List<int> zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    for (final file in archive.files) {
      if (file.name.toLowerCase().endsWith('.json')) {
        return restore(utf8.decode(file.content));
      }
    }
    throw const FormatException('zip 中未找到备份 JSON 文件');
  }

  /// 导出完整项目包：工作区全部文件 + 全量数据 JSON，打包为 zip。
  ///
  /// 覆盖「整个项目（代码、配置、资源、会话记录）导出 zip」需求；
  /// 手机与电脑之间可相互导入文件（数据部分通过本页「从文件恢复」写回）。
  static Future<File> packProject() async {
    final json = await toJson();
    final jsonBytes = utf8.encode(json);
    final files = await FileService.list();

    final archive = Archive()
      ..addFile(ArchiveFile('ai_nexus_backup.json', jsonBytes.length, jsonBytes));
    for (final f in files) {
      final bytes = await File(f.path).readAsBytes();
      archive.addFile(ArchiveFile(f.name, bytes.length, bytes));
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('zip 编码失败');
    }
    final docs = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final out = File(
        '${docs.path}${Platform.pathSeparator}ai_nexus_project_$stamp.zip');
    await out.writeAsBytes(zipBytes, flush: true);
    dev.log(
      '导出项目包 path=${out.path} files=${files.length} size=${zipBytes.length}',
      name: _tag,
    );
    return out;
  }
}