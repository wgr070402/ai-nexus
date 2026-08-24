/// 文件类型（按扩展名归类，用于图标与展示）。
enum AppFileType { image, archive, text, code, other }

/// 工作区中的一个文件（导入后即存在于应用沙盒 workspace 目录）。
class AppFile {
  AppFile({
    required this.name,
    required this.path,
    required this.size,
    required this.type,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String name;
  final String path;
  final int size;
  final AppFileType type;
  final DateTime createdAt;

  bool get isImage => type == AppFileType.image;
  bool get isArchive => type == AppFileType.archive;

  /// 依据文件名推断类型。
  static AppFileType typeOf(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (const <String>{'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic'}
        .contains(ext)) {
      return AppFileType.image;
    }
    if (const <String>{
      'zip', 'tar', 'gz', 'tgz', '7z', 'rar', 'xz', 'bz2',
    }.contains(ext)) {
      return AppFileType.archive;
    }
    if (const <String>{
      'dart', 'py', 'js', 'ts', 'jsx', 'tsx', 'java', 'kt', 'c', 'cpp', 'h',
      'go', 'rs', 'sh', 'rb', 'php', 'swift', 'css', 'html', 'json', 'yaml',
      'yml', 'xml', 'md',
    }.contains(ext)) {
      return AppFileType.code;
    }
    if (const <String>{
      'txt', 'log', 'csv', 'toml', 'ini', 'cfg', 'conf',
    }.contains(ext)) {
      return AppFileType.text;
    }
    return AppFileType.other;
  }

  /// 是否可安全作为纯文本读取。
  bool get isTextReadable =>
      type == AppFileType.text || type == AppFileType.code;
}