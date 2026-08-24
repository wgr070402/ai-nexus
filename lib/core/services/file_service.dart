import 'dart:developer' as dev;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/file_models.dart';

/// 文件服务：应用沙盒 workspace 内的文件读写、zip 打包/解包。
///
/// 所有操作仅作用于 `<appDocuments>/workspace`，不触碰系统其它目录，
/// 符合「以 Workspace 为沙盒」的安全约定。
class FileService {
  FileService._();

  static const String _tag = 'FileService';

  /// 工作区根目录（不存在则创建）。
  static Future<Directory> workspace() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}workspace');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      dev.log('创建 workspace：${dir.path}', name: _tag);
    }
    return dir;
  }

  /// 列出工作区内所有文件。
  static Future<List<AppFile>> list() async {
    final dir = await workspace();
    final files = <AppFile>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      files.add(AppFile(
        name: _baseName(entity.path),
        path: entity.path,
        size: stat.size,
        type: AppFile.typeOf(_baseName(entity.path)),
        createdAt: stat.modified,
      ));
    }
    files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    dev.log('列出文件 count=${files.length}', name: _tag);
    return files;
  }

  /// 将 picker 选中的平台文件复制进工作区。
  static Future<AppFile> importPicked(PlatformFile file) async {
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) {
      throw StateError('无法读取文件内容：${file.name}');
    }
    final dir = await workspace();
    final name = _dedupeName(dir, file.name);
    final dest = File('${dir.path}${Platform.pathSeparator}$name');
    await dest.writeAsBytes(bytes, flush: true);
    dev.log(
      '导入文件 name=$name size=${bytes.length} 字节',
      name: _tag,
    );
    return AppFile(
      name: name,
      path: dest.path,
      size: bytes.length,
      type: AppFile.typeOf(name),
    );
  }

  /// 删除工作区文件。
  static Future<void> delete(AppFile file) async {
    try {
      await File(file.path).delete();
      dev.log('删除文件 name=${file.name}', name: _tag);
    } catch (e) {
      dev.log('删除文件失败 name=${file.name} error=$e',
          name: _tag, error: e);
    }
  }

  /// 读取文本文件内容（仅 text/code 类型）。
  static Future<String> readText(AppFile file) async {
    final content = await File(file.path).readAsString();
    dev.log(
      '读取文本 name=${file.name} chars=${content.length}',
      name: _tag,
    );
    return content;
  }

  /// 将文本内容写入工作区（用于 AI 生成代码、工作区保存等场景）。
  static Future<AppFile> saveText(String name, String content) async {
    final dir = await workspace();
    final safeName = _dedupeName(dir, name);
    final out = File('${dir.path}${Platform.pathSeparator}$safeName');
    await out.writeAsString(content, flush: true);
    dev.log(
      '写入文本 name=$safeName chars=${content.length}',
      name: _tag,
    );
    return AppFile(
      name: safeName,
      path: out.path,
      size: content.length,
      type: AppFile.typeOf(safeName),
    );
  }

  /// 将多个文件打包为 zip（输出到工作区）。
  static Future<AppFile> zip(List<AppFile> files, String zipName) async {
    final archive = Archive();
    for (final f in files) {
      final bytes = await File(f.path).readAsBytes();
      archive.addFile(ArchiveFile(f.name, bytes.length, bytes));
    }
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('zip 编码失败');
    }
    final dir = await workspace();
    final fullName = zipName.endsWith('.zip') ? zipName : '$zipName.zip';
    final out = File('${dir.path}${Platform.pathSeparator}$fullName');
    await out.writeAsBytes(zipBytes, flush: true);
    dev.log(
      '打包 zip name=$fullName files=${files.length} size=${zipBytes.length}',
      name: _tag,
    );
    return AppFile(
      name: fullName,
      path: out.path,
      size: zipBytes.length,
      type: AppFileType.archive,
    );
  }

  /// 解包 zip 到工作区，返回解出的文件列表。
  static Future<List<AppFile>> unzip(AppFile zipFile) async {
    final bytes = await File(zipFile.path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dir = await workspace();
    final extracted = <AppFile>[];
    for (final f in archive.files) {
      final sub = f.name.replaceAll('\\', Platform.pathSeparator);
      final out = File('${dir.path}${Platform.pathSeparator}$sub');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(f.content, flush: true);
      extracted.add(AppFile(
        name: _baseName(out.path),
        path: out.path,
        size: f.size,
        type: AppFile.typeOf(_baseName(out.path)),
      ));
    }
    dev.log('解包 zip name=${zipFile.name} extracted=${extracted.length}', name: _tag);
    return extracted;
  }

  static String _baseName(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    return idx < 0 ? path : path.substring(idx + 1);
  }

  /// 若同名文件已存在，追加序号避免覆盖。
  static String _dedupeName(Directory dir, String name) {
    final dot = name.lastIndexOf('.');
    final stem = dot < 0 ? name : name.substring(0, dot);
    final ext = dot < 0 ? '' : name.substring(dot);
    var candidate = name;
    var i = 1;
    while (File('${dir.path}${Platform.pathSeparator}$candidate').existsSync()) {
      candidate = '$stem($i)$ext';
      i++;
    }
    return candidate;
  }
}