import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/knowledge_models.dart';
import '../../core/services/knowledge_controller.dart';

/// 知识库板块：文档管理、搜索、手写 / 导入。
///
/// 本地文件上传读取依赖系统文件选择器（需真机 + 授权），本版先提供
/// 「粘贴导入」与「手写」两条可信路径；文件选择器后续接入。
class KnowledgePage extends StatefulWidget {
  const KnowledgePage({super.key});

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  final KnowledgeController _controller = KnowledgeController();
  final TextEditingController _search = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor({KnowledgeDoc? doc}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DocEditor(doc: doc, onSave: _controller.save),
    );
    setState(() {});
  }

  Future<void> _openDetail(KnowledgeDoc doc) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DocDetailPage(doc: doc),
      ),
    );
    setState(() {});
  }

  Future<void> _confirmDelete(KnowledgeDoc doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('删除文档'),
        content: Text('确定删除「${doc.title}」吗？'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) await _controller.delete(doc.id);
  }

  @override
  Widget build(BuildContext context) {
    final docs = _controller.search(_keyword);
    return Scaffold(
      appBar: AppBar(title: const Text('知识库')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, _) {
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _search,
                  onChanged: (String v) => setState(() => _keyword = v),
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search,
                        size: 20, color: AppColors.textMuted),
                    hintText: '搜索标题 / 内容 / 标签',
                    hintStyle:
                        const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: docs.isEmpty
                    ? _emptyState(_keyword.isEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (BuildContext context, int index) =>
                            _docCard(docs[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState(bool noKeyword) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.menu_book_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(noKeyword ? '暂无文档' : '无匹配结果',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('点击右下角新建文档',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _docCard(KnowledgeDoc doc) {
    return InkWell(
      onTap: () => _openDetail(doc),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                if (doc.sourceType == 'import')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('导入',
                        style: TextStyle(fontSize: 10, color: AppColors.accent)),
                  ),
                IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.textSecondary),
                    onPressed: () => _openEditor(doc: doc),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.danger),
                    onPressed: () => _confirmDelete(doc),
                  ),
              ],
            ),
            if (doc.category.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(doc.category,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.primaryLight)),
              ),
            if (doc.content.isNotEmpty)
              Text(doc.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary)),
            if (doc.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: doc.tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text('#$t',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary)),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 文档编辑器（新建 / 编辑）。
class _DocEditor extends StatefulWidget {
  const _DocEditor({required this.doc, required this.onSave});
  final KnowledgeDoc? doc;
  final Future<void> Function(KnowledgeDoc) onSave;

  @override
  State<_DocEditor> createState() => _DocEditorState();
}

class _DocEditorState extends State<_DocEditor> {
  late final TextEditingController _title =
      TextEditingController(text: widget.doc?.title ?? '');
  late final TextEditingController _category =
      TextEditingController(text: widget.doc?.category ?? '');
  late final TextEditingController _tags = TextEditingController(
      text: (widget.doc?.tags ?? <String>[]).join(', '));
  late final TextEditingController _content =
      TextEditingController(text: widget.doc?.content ?? '');

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _tags.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写文档标题')),
      );
      return;
    }
    final tags = _tags.text
        .split(RegExp(r'[,，]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final doc = KnowledgeDoc(
      id: widget.doc?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      content: _content.text.trim(),
      category: _category.text.trim(),
      tags: tags,
      sourceType: widget.doc?.sourceType ?? 'manual',
      createdAt: widget.doc?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    dev.log('编辑保存 title=$title content=${doc.content.length}字符 tags=${tags.length}',
        name: 'Knowledge');
    await widget.onSave(doc);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(widget.doc == null ? '新建文档' : '编辑文档',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            _field(_title, '标题'),
            const SizedBox(height: 12),
            _field(_category, '分类'),
            const SizedBox(height: 12),
            _field(_tags, '标签（逗号分隔）'),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              maxLines: 8,
              minLines: 4,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: _dec('内容'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('保存')),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      decoration: _dec(label),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      );
}

/// 文档详情页（全文 + 编辑）。
class _DocDetailPage extends StatelessWidget {
  const _DocDetailPage({required this.doc});
  final KnowledgeDoc doc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (doc.category.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('分类：${doc.category}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.primaryLight)),
            ),
          if (doc.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('标签：${doc.tags.map((t) => '#$t').join('  ')}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ),
          const Divider(),
          const SizedBox(height: 8),
          Text(doc.content.isEmpty ? '（无内容）' : doc.content,
              style: const TextStyle(
                  fontSize: 14, height: 1.6, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}