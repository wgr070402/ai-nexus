import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/services/backup_service.dart';

/// 数据备份与恢复页面。
///
/// 一键导出全量数据为 JSON（复制到剪贴板）并打包 zip 到应用文档目录；
/// 支持粘贴 JSON 或选择 zip / json 文件恢复，恢复前进行覆盖二次确认。
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json = await BackupService.toJson();
      await Clipboard.setData(ClipboardData(text: json));
      final zipFile = await BackupService.toZip(json);
      dev.log('备份导出完成 zip=${zipFile.path}', name: 'BackupPage');
      _snack('备份完成：JSON 已复制到剪贴板，zip 已保存到应用文档目录');
    } catch (e) {
      dev.log('备份失败：$e', name: 'BackupPage', error: e);
      _snack('备份失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 导出完整项目包：工作区文件 + 全量数据 JSON 打包 zip。
  Future<void> _packProject() async {
    setState(() => _busy = true);
    try {
      final file = await BackupService.packProject();
      dev.log('项目包导出完成 path=${file.path}', name: 'BackupPage');
      _snack('项目包已导出：${file.path}');
    } catch (e) {
      dev.log('项目包导出失败：$e', name: 'BackupPage', error: e);
      _snack('项目包导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importPaste() async {
    final controller = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('恢复备份（JSON）'),
        content: SizedBox(
          width: double.maxFinite,
          height: 240,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: '粘贴备份 JSON …'),
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('恢复')),
        ],
      ),
    );
    controller.dispose();
    if (json == null || json.trim().isEmpty) return;
    await _confirmAndRestore(() => BackupService.restore(json));
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['zip', 'json'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) {
      _snack('无法读取所选文件');
      return;
    }
    final isJson = file.name.toLowerCase().endsWith('.json');
    await _confirmAndRestore(() async {
      if (isJson) {
        return BackupService.restore(utf8.decode(bytes));
      }
      return BackupService.restoreZip(bytes);
    });
  }

  Future<void> _confirmAndRestore(Future<int> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认恢复'),
        content: const Text(
            '恢复将覆盖现有的模型、Agent、技能、工作流、知识库、群聊、单聊与终端数据，且不可撤销。是否继续？'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('覆盖并恢复')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final count = await action();
      dev.log('恢复完成 count=$count', name: 'BackupPage');
      _snack('恢复成功，共更新 $count 项数据（建议重启应用生效）');
    } catch (e) {
      dev.log('恢复失败：$e', name: 'BackupPage', error: e);
      _snack('恢复失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const _InfoText(),
          const SizedBox(height: 16),
          _actionTile(
            icon: Icons.backup_outlined,
            title: '导出备份',
            subtitle: '导出全部数据为 JSON 并打包 zip',
            color: AppColors.primaryLight,
            onTap: _busy ? null : _export,
          ),
          const SizedBox(height: 12),
          _actionTile(
            icon: Icons.archive_outlined,
            title: '导出项目包',
            subtitle: '工作区全部文件 + 数据 JSON 打包 zip（手机电脑互导）',
            color: AppColors.success,
            onTap: _busy ? null : _packProject,
          ),
          const SizedBox(height: 12),
          _actionTile(
            icon: Icons.paste_outlined,
            title: '从 JSON 恢复',
            subtitle: '粘贴备份 JSON 文本覆盖恢复',
            color: AppColors.accent,
            onTap: _busy ? null : _importPaste,
          ),
          const SizedBox(height: 12),
          _actionTile(
            icon: Icons.folder_zip_outlined,
            title: '从文件恢复',
            subtitle: '选择备份 zip / json 文件覆盖恢复',
            color: AppColors.warning,
            onTap: _busy ? null : _importFile,
          ),
          const SizedBox(height: 16),
          const _SecurityNote(),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        '备份范围：模型配置、Agent、技能、工作流、知识库、群聊、单聊会话、终端会话。',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.security_outlined, size: 18, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '安全说明：API Key 存于系统安全存储（Keystore），不会随备份导出；'
              '恢复备份不会覆盖已保存的 API Key，请放心使用。',
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}