import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/app_constants.dart';
import '../codex/codex_page.dart';
import '../files/files_page.dart';
import '../generator/generator_page.dart';
import '../harness/harness_page.dart';
import '../knowledge/knowledge_page.dart';
import '../models/models_page.dart';
import '../projects/projects_page.dart';
import '../skills/skill_page.dart';
import '../terminal/terminal_page.dart';
import '../workflow/workflow_page.dart';
import '../workspace/code_workspace_page.dart';
import 'backup_page.dart';

/// 设置板块。
///
/// 顶部提供搜索框：输入关键字后实时过滤所有设置项并直接跳转（参考
/// RikkaHub fork 的「Settings search」能力）。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// 可被搜索并跳转的设置项（覆盖所有功能入口）。
  late final List<_SettingEntry> _entries = <_SettingEntry>[
    _SettingEntry(
      title: '模型中心',
      subtitle: '管理多服务商模型、API Key 与默认模型',
      icon: Icons.hub_outlined,
      keywords: 'model api key 模型 服务商',
      builder: (_) => const ModelsPage(),
    ),
    _SettingEntry(
      title: '文件中心',
      subtitle: '上传文件/图片/压缩包，zip 打包解包、导入知识库',
      icon: Icons.folder_open_outlined,
      keywords: 'file 文件 图片 上传 zip 附件',
      builder: (_) => const FilesPage(),
    ),
    _SettingEntry(
      title: '数据备份与恢复',
      subtitle: '一键导出全量数据为 JSON/zip，覆盖恢复',
      icon: Icons.backup_outlined,
      keywords: 'backup restore 备份 恢复 导出 导入 数据',
      builder: (_) => const BackupPage(),
    ),
    _SettingEntry(
      title: 'AI 生成器',
      subtitle: '生成 Demo/脚手架/注释/测试/游戏/文档/脚本/数据/流程图',
      icon: Icons.auto_awesome_outlined,
      keywords: 'generate 生成 demo 脚手架 测试 游戏 文档 脚本 mermaid 流程图',
      builder: (_) => const GeneratorPage(),
    ),
    _SettingEntry(
      title: '代码工作区',
      subtitle: '多文件 tab 编辑源码，AI 批量读写重构',
      icon: Icons.code_outlined,
      keywords: 'code workspace 代码 工作区 多文件 编辑 重构',
      builder: (_) => const CodeWorkspacePage(),
    ),
    _SettingEntry(
      title: 'DeepSeek Harness',
      subtitle: '连接独立执行服务，远程运行代码与测试',
      icon: Icons.hub_outlined,
      keywords: 'runtime harness deepseek 运行时 执行 代码',
      builder: (_) => const DeepSeekHarnessPage(),
    ),
    _SettingEntry(
      title: 'Codex',
      subtitle: '对接 OpenAI Codex / Responses API 生成代码',
      icon: Icons.code_outlined,
      keywords: 'codex openai 代码 生成',
      builder: (_) => const CodexPage(),
    ),
    _SettingEntry(
      title: '工作流',
      subtitle: '多 Agent 协作工作流编排与顺序执行',
      icon: Icons.account_tree_outlined,
      keywords: 'workflow 工作流 编排 多agent 协作',
      builder: (_) => const WorkflowPage(),
    ),
    _SettingEntry(
      title: '知识库',
      subtitle: '管理文档知识，支持搜索与引用',
      icon: Icons.menu_book_outlined,
      keywords: 'knowledge 知识库 文档 搜索',
      builder: (_) => const KnowledgePage(),
    ),
    _SettingEntry(
      title: '技能',
      subtitle: '管理技能指令模板，启停与预览',
      icon: Icons.extension_outlined,
      keywords: 'skill 技能 指令 模板',
      builder: (_) => const SkillPage(),
    ),
    _SettingEntry(
      title: '项目',
      subtitle: '运行时环境检测、项目类型识别与运行测试',
      icon: Icons.folder_outlined,
      keywords: 'project 项目 运行时 环境 运行 测试',
      builder: (_) => const ProjectsPage(),
    ),
    _SettingEntry(
      title: '终端',
      subtitle: '内置终端，运行命令查看输出',
      icon: Icons.terminal_outlined,
      keywords: 'terminal 终端 命令 shell 运行',
      builder: (_) => const TerminalPage(),
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_SettingEntry> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    return _entries.where((e) => e.matches(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              cursorColor: AppColors.primaryLight,
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索设置项…',
                hintStyle:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon:
                    const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close,
                            size: 16, color: AppColors.textMuted),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: AppColors.surfaceLight,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
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
            child: _query.trim().isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      _AboutCard(),
                      const SizedBox(height: 16),
                      const _FeaturesCard(),
                      const SizedBox(height: 16),
                      const _RuntimeLinksCard(),
                      const SizedBox(height: 16),
                      const _ModelCenterCard(),
                      const SizedBox(height: 16),
                      const _FileCenterCard(),
                      const SizedBox(height: 16),
                      const _ToolsCard(),
                      const SizedBox(height: 16),
                      const _BackupCard(),
                    ],
                  )
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = _filtered;
    if (results.isEmpty) {
      return const Center(
        child: Text('未找到匹配的设置项',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final entry = results[index];
        return _RuntimeLinkTile(
          icon: entry.icon,
          title: entry.title,
          subtitle: entry.subtitle,
          onTap: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: entry.builder),
            );
          },
        );
      },
    );
  }
}

/// 一条可搜索的设置项。
class _SettingEntry {
  const _SettingEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
    this.keywords = '',
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
  final String keywords;

  bool matches(String query) {
    final hay = '${title.toLowerCase()} ${subtitle.toLowerCase()} '
        '${keywords.toLowerCase()}';
    return hay.contains(query);
  }
}

class _FileCenterCard extends StatelessWidget {
  const _FileCenterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text('数据',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ),
          _RuntimeLinkTile(
            icon: Icons.folder_open_outlined,
            title: '文件中心',
            subtitle: '上传文件/图片/压缩包，zip 打包解包、导入知识库',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const FilesPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text('功能',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ),
          _RuntimeLinkTile(
            icon: Icons.account_tree_outlined,
            title: '工作流',
            subtitle: '多 Agent 协作工作流编排与顺序执行',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const WorkflowPage(),
              ),
            ),
          ),
          _RuntimeLinkTile(
            icon: Icons.menu_book_outlined,
            title: '知识库',
            subtitle: '管理文档知识，支持搜索与引用',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const KnowledgePage(),
              ),
            ),
          ),
          _RuntimeLinkTile(
            icon: Icons.extension_outlined,
            title: '技能',
            subtitle: '管理技能指令模板，启停与预览',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SkillPage(),
              ),
            ),
          ),
          _RuntimeLinkTile(
            icon: Icons.folder_outlined,
            title: '项目',
            subtitle: '运行时环境检测、项目类型识别与运行测试',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProjectsPage(),
              ),
            ),
          ),
          _RuntimeLinkTile(
            icon: Icons.terminal_outlined,
            title: '终端',
            subtitle: '内置终端，运行命令查看输出',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TerminalPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolsCard extends StatelessWidget {
  const _ToolsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text('工具',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ),
          _RuntimeLinkTile(
            icon: Icons.auto_awesome_outlined,
            title: 'AI 生成器',
            subtitle: '生成 Demo/脚手架/注释/测试/游戏/文档/脚本/数据/流程图',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GeneratorPage(),
              ),
            ),
          ),
          _RuntimeLinkTile(
            icon: Icons.code_outlined,
            title: '代码工作区',
            subtitle: '多文件 tab 编辑源码，AI 批量读写重构',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CodeWorkspacePage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text('维护',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ),
          _RuntimeLinkTile(
            icon: Icons.backup_outlined,
            title: '数据备份与恢复',
            subtitle: '导出全部数据为 JSON/zip，覆盖恢复',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BackupPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCenterCard extends StatelessWidget {
  const _ModelCenterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text('模型',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ),
          _RuntimeLinkTile(
            icon: Icons.hub_outlined,
            title: '模型中心',
            subtitle: '管理多服务商模型、API Key 与默认模型',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ModelsPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hub_outlined,
                    size: 24, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(AppConstants.appName,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text(AppConstants.appTagline,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          _InfoRow(label: '版本', value: AppConstants.appVersion),
          const SizedBox(height: 8),
          const _InfoRow(label: '主题', value: '深色科技风'),
          const SizedBox(height: 8),
          const _InfoRow(label: '状态', value: 'Phase 1 · 项目初始化'),
        ],
      ),
    );
  }
}

class _RuntimeLinksCard extends StatelessWidget {
  const _RuntimeLinksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text('运行时',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ),
          _RuntimeLinkTile(
            icon: Icons.hub_outlined,
            title: 'DeepSeek Harness',
            subtitle: '连接独立执行服务，远程运行代码与测试',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DeepSeekHarnessPage(),
              ),
            ),
          ),
          _RuntimeLinkTile(
            icon: Icons.code_outlined,
            title: 'Codex',
            subtitle: '对接 OpenAI Codex / Responses API 生成代码',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CodexPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeLinkTile extends StatelessWidget {
  const _RuntimeLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryLight, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary)),
      ],
    );
  }
}