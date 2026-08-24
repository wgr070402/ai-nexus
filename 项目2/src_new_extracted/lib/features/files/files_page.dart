import 'dart:developer' as dev;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/file_models.dart';
import '../../core/models/knowledge_models.dart';
import '../../core/services/file_service.dart';
import '../../core/services/knowledge_controller.dart';

/// 文件中心：文件/图片/压缩包上传、预览、zip 打包/解包、导入知识库。
///
/// 所有文件存于应用沙盒 workspace 目录，符合安全约束。
class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  List<AppFile> _files = <AppFile>[];
  final Set<String> _selected = <String>{};
  bool _selecting = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final files = await FileService.list();
    if (!mounted) return;
    setState(() => _files = files);
  }

  Future<void> _pick(FileType type, {List<String>? extensions}) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: extensions,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _busy = true);
    var count = 0;
    for (final f in result.files) {
      try {
        await FileService.importPicked(f);
        count++;
      } catch (e) {
        dev.log('导入失败 name=${f.name} error=$e', name: 'FileCenter', error: e);
      }
    }
    setState(() => _busy = false);
    if (count > 0) _snack('已导入 $count 个文件');
    _refresh();
  }

  Future<void> _openPickerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择上传类型',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined,
                  color: AppColors.primaryLight),
              title: const Text('文件', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.of(context).pop();
                _pick(FileType.any);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppColors.primaryLight),
              title: const Text('图片', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.of(context).pop();
                _pick(FileType.image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_zip_outlined,
                  color: AppColors.primaryLight),
              title: const Text('压缩包', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.of(context).pop();
                _pick(FileType.custom,
                    extensions: const <String>[
                      'zip', 'tar', 'gz', 'tgz', '7z', 'rar', 'bz2', 'xz',
                    ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unzip(AppFile file) async {
    setState(() => _busy = true);
    try {
      final extracted = await FileService.unzip(file);
      _snack('解压完成，共 ${extracted.length} 个文件');
    } catch (e) {
      dev.log('解压失败 name=${file.name} error=$e', name: 'FileCenter', error: e);
      _snack('解压失败：$e');
    }
    setState(() => _busy = false);
    _refresh();
  }

  Future<void> _importToKnowledge(AppFile file) async {
    final content = await FileService.readText(file);
    final controller = KnowledgeController();
    await controller.init();
    await controller.save(KnowledgeDoc(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: file.name,
      content: content,
      sourceType: 'import',
    ));
    dev.log('导入知识库 title=${file.name} chars=${content.length}', name: 'FileCenter');
    _snack('已导入知识库：${file.name}');
  }

  Future<void> _packSelected() async {
    final selected = _files.where((f) => _selected.contains(f.name)).toList();
    if (selected.isEmpty) {
      _snack('请先勾选要打包的文件');
      return;
    }
    setState(() => _busy = true);
    try {
      final zip = await FileService.zip(
        selected,
        'pack_${DateTime.now().millisecondsSinceEpoch}',
      );
      _snack('已打包：${zip.name}');
      setState(() {
        _selecting = false;
        _selected.clear();
      });
    } catch (e) {
      dev.log('打包失败 error=$e', name: 'FileCenter', error: e);
      _snack('打包失败：$e');
    }
    setState(() => _busy = false);
    _refresh();
  }

  Future<void> _preview(AppFile file) async {
    if (file.isImage) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black87,
            appBar: AppBar(title: Text(file.name)),
            body: Center(
              child: InteractiveViewer(
                child: Image.file(File(file.path)),
              ),
            ),
          ),
        ),
      );
      return;
    }
    if (file.isTextReadable) {
      final content = await FileService.readText(file);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: Text(content,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.textPrimary)),
            ),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭')),
          ],
        ),
      );
      return;
    }
    _snack('该类型暂不支持预览（${file.name}）');
  }

  Future<void> _confirmDelete(AppFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('删除文件'),
        content: Text('确定删除「${file.name}」吗？'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await FileService.delete(file);
      _refresh();
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件中心'),
        actions: <Widget>[
          if (_files.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() {
                _selecting = !_selecting;
                _selected.clear();
              }),
              icon: Icon(_selecting ? Icons.close : Icons.inventory_2_outlined,
                  size: 18),
              label: Text(_selecting ? '取消' : '打包ZIP'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : _openPickerSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _selecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _packSelected,
                  icon: const Icon(Icons.archive_outlined),
                  label: Text('打包所选 (${_selected.length})'),
                ),
              ),
            )
          : null,
      body: _files.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.folder_open_outlined,
                      size: 48, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('工作区为空',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  SizedBox(height: 6),
                  Text('点击右下角上传文件 / 图片 / 压缩包',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _files.length,
              itemBuilder: (BuildContext context, int index) =>
                  _fileCard(_files[index]),
            ),
    );
  }

  Widget _fileCard(AppFile file) {
    final selected = _selected.contains(file.name);
    return InkWell(
      onTap: _selecting
          ? () => setState(() => _toggle(file.name))
          : () => _preview(file),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            if (_selecting)
              Checkbox(
                value: selected,
                activeColor: AppColors.primary,
                onChanged: (_) => setState(() => _toggle(file.name)),
              ),
            _typeIcon(file),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('${_sizeLabel(file.size)} · ${_dateLabel(file.createdAt)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (!_selecting) ...<Widget>[
              if (file.isArchive)
                IconButton(
                  tooltip: '解压',
                  icon: const Icon(Icons.unarchive_outlined,
                      size: 18, color: AppColors.primaryLight),
                  onPressed: () => _unzip(file),
                ),
              if (file.isTextReadable)
                IconButton(
                  tooltip: '导入知识库',
                  icon: const Icon(Icons.menu_book_outlined,
                      size: 18, color: AppColors.textSecondary),
                  onPressed: () => _importToKnowledge(file),
                ),
              IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.danger),
                onPressed: () => _confirmDelete(file),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _toggle(String name) {
    if (_selected.contains(name)) {
      _selected.remove(name);
    } else {
      _selected.add(name);
    }
  }

  Widget _typeIcon(AppFile file) {
    final (IconData icon, Color color) = switch (file.type) {
      AppFileType.image => (Icons.image_outlined, AppColors.success),
      AppFileType.archive => (Icons.folder_zip_outlined, AppColors.warning),
      AppFileType.code => (Icons.code_outlined, AppColors.primaryLight),
      AppFileType.text => (Icons.description_outlined, AppColors.textSecondary),
      AppFileType.other =>
        (Icons.insert_drive_file_outlined, AppColors.textMuted),
    };
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }

  static String _sizeLabel(int size) {
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '$size B';
  }

  static String _dateLabel(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}