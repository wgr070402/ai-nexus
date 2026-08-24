import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../runtime/environment_manager.dart';
import '../../runtime/runtime_adapter.dart';
import '../../runtime/runtime_result.dart';
import '../../runtime/termux_runtime_adapter.dart';
import 'auto_fix_page.dart';

/// 项目板块：接入 Runtime Manager，提供运行时环境调度能力。
///
/// 功能：
///  - 环境检测：探测 Python / Node / Git / C/C++ / Rust / Go 等是否就绪；
///  - 项目识别：根据工作目录文件特征识别语言 / 项目类型 / 推荐运行时；
///  - 依赖检查：列出项目所需命令已装 / 缺失；
///  - 运行 / 测试：通过 TermuxRuntimeAdapter 执行真实命令并回显结果。
///
/// Android 本地完整运行时依赖 Termux；未装 Termux 时本地 shell 能力有限，
/// 结果均如实返回，绝不伪造。
class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final RuntimeAdapter _runtime = const TermuxRuntimeAdapter();

  final TextEditingController _workspace = TextEditingController(
    text: '/data/data/com.termux/files/home',
  );

  EnvironmentReport? _env;
  bool _envLoading = false;

  RuntimeDetectResult? _detection;
  bool _detectLoading = false;

  DependencyCheckResult? _deps;
  bool _depsLoading = false;

  /// 最近一次运行 / 测试结果。
  RuntimeResult? _lastResult;
  String? _execAction;
  bool _execLoading = false;

  @override
  void dispose() {
    _workspace.dispose();
    super.dispose();
  }

  Future<void> _detectEnv() async {
    setState(() => _envLoading = true);
    try {
      final report = await EnvironmentManager.detect();
      if (!mounted) return;
      setState(() => _env = report);
    } catch (e) {
      _snack('环境检测失败：$e');
    } finally {
      if (mounted) setState(() => _envLoading = false);
    }
  }

  Future<void> _detectProject() async {
    final path = _workspace.text.trim();
    if (path.isEmpty) {
      _snack('请输入项目目录路径');
      return;
    }
    setState(() => _detectLoading = true);
    try {
      final detection = await _runtime.detect(projectPath: path);
      if (!mounted) return;
      setState(() {
        _detection = detection;
        _deps = null; // 项目变化后依赖结果作废
      });
    } catch (e) {
      _snack('项目识别失败：$e');
    } finally {
      if (mounted) setState(() => _detectLoading = false);
    }
  }

  Future<void> _checkDeps() async {
    final detection = _detection;
    if (detection == null) {
      _snack('请先识别项目类型');
      return;
    }
    setState(() => _depsLoading = true);
    try {
      final deps = await _runtime.checkDeps(
        detection: detection,
        workspace: _workspace.text.trim(),
      );
      if (!mounted) return;
      setState(() => _deps = deps);
    } catch (e) {
      _snack('依赖检查失败：$e');
    } finally {
      if (mounted) setState(() => _depsLoading = false);
    }
  }

  Future<void> _execute({required String action, String? command}) async {
    final path = _workspace.text.trim();
    if (path.isEmpty) {
      _snack('请输入项目目录路径');
      return;
    }
    final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _execAction = action;
      _execLoading = true;
      _lastResult = null;
    });
    try {
      final RuntimeResult result;
      switch (action) {
        case 'run':
          result = await _runtime.run(sessionId: sessionId, workspace: path, command: command);
          break;
        case 'test':
          result = await _runtime.test(sessionId: sessionId, workspace: path, command: command);
          break;
        default:
          result = await _runtime.build(sessionId: sessionId, workspace: path);
      }
      if (!mounted) return;
      setState(() => _lastResult = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastResult = RuntimeResult(
            success: false,
            runtime: 'none',
            command: command ?? action,
            stderr: e.toString(),
            errorSummary: e.toString(),
          ));
    } finally {
      if (mounted) setState(() => _execLoading = false);
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
      appBar: AppBar(title: const Text('项目')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildEnvironmentCard(),
          const SizedBox(height: 16),
          _buildProjectCard(),
          if (_lastResult != null) ...<Widget>[
            const SizedBox(height: 16),
            _buildResultCard(_lastResult!),
          ],
        ],
      ),
    );
  }

  /// 环境状态卡片。
  Widget _buildEnvironmentCard() {
    return _SectionCard(
      title: '运行时环境',
      icon: Icons.memory_outlined,
      action: TextButton(
        onPressed: _envLoading ? null : _detectEnv,
        child: Text(_envLoading ? '检测中…' : '检测环境',
            style: const TextStyle(fontSize: 13)),
      ),
      child: _env == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('尚未检测。点击「检测环境」探测 Python/Node/Git 等运行时是否就绪。',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            )
          : Column(
              children: <Widget>[
                _envExecLine(_env!),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _env!.tools.map(_toolChip).toList(),
                ),
              ],
            ),
    );
  }

  Widget _envExecLine(EnvironmentReport report) {
    final String label = report.executor == 'termux'
        ? '执行通道：Termux（完整 Linux 运行时）'
        : report.executor == 'local'
            ? '执行通道：本地 shell（能力有限，建议安装 Termux）'
            : '执行通道：未知';
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: report.executor == 'termux'
                ? AppColors.success
                : AppColors.warning,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _toolChip(EnvTool tool) {
    final Color color = tool.installed ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(tool.name,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          if (tool.installed && tool.version.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(_trimVersion(tool.version),
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ),
          if (!tool.installed)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('未装',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }

  static String _trimVersion(String version) {
    final v = version.replaceAll(RegExp(r'\s+'), ' ').trim();
    return v.length > 20 ? '${v.substring(0, 20)}…' : v;
  }

  /// 项目识别 + 依赖 + 运行/测试卡片。
  Widget _buildProjectCard() {
    return _SectionCard(
      title: '项目识别与执行',
      icon: Icons.folder_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _workspace,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              labelText: '项目目录（Termux 内绝对路径）',
              hintText: '/data/data/com.termux/files/home/myproj',
              labelStyle:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _detectLoading ? null : _detectProject,
                  icon: const Icon(Icons.search, size: 18),
                  label: Text(_detectLoading ? '识别中…' : '识别项目类型'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_detection == null || _depsLoading) ? null : _checkDeps,
                  icon: const Icon(Icons.checklist_outlined, size: 18),
                  label: Text(_depsLoading ? '检查中…' : '检查依赖'),
                ),
              ),
            ],
          ),
          if (_detection != null) ...<Widget>[
            const SizedBox(height: 12),
            _buildDetectionInfo(_detection!),
          ],
          if (_deps != null) ...<Widget>[
            const SizedBox(height: 8),
            _buildDepsInfo(_deps!),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _execLoading ? null : () => _execute(action: 'run'),
                  icon: const Icon(Icons.play_arrow_outlined, size: 18),
                  label: Text(_execLoading && _execAction == 'run' ? '运行中…' : '▶ 运行'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _execLoading ? null : () => _execute(action: 'test'),
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: Text(_execLoading && _execAction == 'test' ? '测试中…' : '🧪 测试'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionInfo(RuntimeDetectResult d) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('识别结果',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          if (!d.detected)
            const Text('未能识别项目类型（请确认目录存在且包含源码/清单文件）',
                style: TextStyle(fontSize: 13, color: AppColors.warning))
          else
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: <Widget>[
                _infoLabel('语言', d.language),
                _infoLabel('类型', d.projectType),
                _infoLabel('推荐运行时', d.recommendedRuntime),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDepsInfo(DependencyCheckResult deps) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('依赖检查',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Icon(deps.ok ? Icons.check_circle : Icons.error_outline,
                  size: 16,
                  color: deps.ok ? AppColors.success : AppColors.warning),
            ],
          ),
          const SizedBox(height: 6),
          if (deps.ok)
            const Text('所需依赖均已安装。',
                style: TextStyle(fontSize: 13, color: AppColors.success))
          else
            Text('缺失依赖：${deps.missing.join('、')}（用于安装的缺失依赖属高危操作，需二次确认）',
                style: const TextStyle(fontSize: 13, color: AppColors.warning)),
        ],
      ),
    );
  }

  Widget _infoLabel(String label, String value) {
    return Text.rich(
      TextSpan(children: <TextSpan>[
        TextSpan(
            text: '$label：',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        TextSpan(
            text: value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ]),
    );
  }

  /// 执行结果回显卡片。
  Widget _buildResultCard(RuntimeResult result) {
    return _SectionCard(
      title: result.success ? '执行成功' : '执行失败',
      icon: result.success ? Icons.check_circle_outline : Icons.error_outline,
      iconColor: result.success ? AppColors.success : AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('runtime: ${result.runtime} · exit: ${result.exitCode ?? '-'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Text('\$ ${result.command}',
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppColors.accent)),
          if (result.stdout.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _OutputBlock(text: result.stdout, color: AppColors.textSecondary),
          ],
          if (result.stderr.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _OutputBlock(text: result.stderr, color: AppColors.danger),
          ],
          if (result.errorSummary != null && result.errorSummary!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('错误摘要：${result.errorSummary}',
                  style: const TextStyle(fontSize: 12, color: AppColors.warning)),
            ),
          if (!result.success) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _openAutoFix(result),
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: const Text('自动修复'),
            ),
          ],
        ],
      ),
    );
  }

  /// 跳转到自动修复页，带入最近一次失败结果。
  void _openAutoFix(RuntimeResult result) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AutoFixPage(initialResult: result),
      ),
    );
  }
}

/// 通用区块卡片。
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
    this.action,
  });

  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: iconColor ?? AppColors.primaryLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// 等宽输出的可滚动文本块（限制高度，避免超长输出撑破页面）。
class _OutputBlock extends StatelessWidget {
  const _OutputBlock({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: Text(text,
            style: TextStyle(
                color: color, fontFamily: 'monospace', fontSize: 12, height: 1.4)),
      ),
    );
  }
}