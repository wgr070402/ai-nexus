import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/skill_models.dart';
import '../../core/services/skill_controller.dart';

/// 技能库板块：可复用提示词/指令模板的 CRUD 与启停。
class SkillPage extends StatefulWidget {
  const SkillPage({super.key});

  @override
  State<SkillPage> createState() => _SkillPageState();
}

class _SkillPageState extends State<SkillPage> {
  final SkillController _controller = SkillController();

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openEditor({Skill? skill}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SkillEditor(skill: skill, onSave: _controller.save),
    );
    setState(() {});
  }

  Future<void> _confirmDelete(Skill skill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('删除技能'),
        content: Text('确定删除「${skill.name}」吗？'),
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
    if (ok == true) await _controller.delete(skill.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('技能')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, _) {
          if (_controller.skills.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.extension_outlined,
                        size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text('暂无技能',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 6),
                    Text('点击右下角创建可复用提示词技能',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _controller.skills.length,
            itemBuilder: (BuildContext context, int index) {
              final skill = _controller.skills[index];
              return _skillCard(skill);
            },
          );
        },
      ),
    );
  }

  Widget _skillCard(Skill skill) {
    return Container(
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: skill.enabled
                      ? AppColors.primaryGradient
                      : null,
                  color: skill.enabled ? null : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.extension,
                    size: 20,
                    color: skill.enabled ? Colors.white : AppColors.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(skill.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: skill.enabled
                                ? AppColors.textPrimary
                                : AppColors.textMuted)),
                    if (skill.category.isNotEmpty)
                      Text(skill.category,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.primaryLight)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: skill.enabled,
                activeTrackColor: AppColors.primary,
                onChanged: (_) => _controller.toggleEnabled(skill.id),
              ),
            ],
          ),
          if (skill.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(skill.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
          if (skill.instruction.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(skill.instruction,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton.icon(
                onPressed: () => _openEditor(skill: skill),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('编辑'),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => _confirmDelete(skill),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('删除'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 技能编辑器（新建 / 编辑）。
class _SkillEditor extends StatefulWidget {
  const _SkillEditor({required this.skill, required this.onSave});
  final Skill? skill;
  final Future<void> Function(Skill) onSave;

  @override
  State<_SkillEditor> createState() => _SkillEditorState();
}

class _SkillEditorState extends State<_SkillEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.skill?.name ?? '');
  late final TextEditingController _category =
      TextEditingController(text: widget.skill?.category ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.skill?.description ?? '');
  late final TextEditingController _instruction =
      TextEditingController(text: widget.skill?.instruction ?? '');

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _description.dispose();
    _instruction.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写技能名称')),
      );
      return;
    }
    final skill = Skill(
      id: widget.skill?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      category: _category.text.trim(),
      description: _description.text.trim(),
      instruction: _instruction.text.trim(),
      enabled: widget.skill?.enabled ?? true,
      createdAt: widget.skill?.createdAt ?? DateTime.now(),
    );
    await widget.onSave(skill);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(widget.skill == null ? '新建技能' : '编辑技能',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 14),
              _field(_name, '名称'),
              const SizedBox(height: 12),
              _field(_category, '分类'),
              const SizedBox(height: 12),
              _field(_description, '一句话描述'),
              const SizedBox(height: 12),
              TextField(
                controller: _instruction,
                maxLines: 6,
                minLines: 3,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                decoration: _dec('指令 / 提示词模板'),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('保存')),
            ],
          ),
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