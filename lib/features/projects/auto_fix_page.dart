import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/chat_models.dart';
import '../../core/services/app_storage.dart';
import '../../runtime/auto_fixer.dart';
import '../../runtime/error_analyzer.dart';
import '../../runtime/runtime_result.dart';
import '../../services/termux_bridge.dart';

/// 自动修复页面：错误分析 → LLM 生成修复 → （确认后）写回文件。
///
/// 可从「项目」页执行失败后跳入，自动带入最近一次错误。
class AutoFixPage extends StatefulWidget {
  const AutoFixPage({super.key, this.initialResult});

  /// 初始错误结果（来自项目页运行/测试失败）。
  final RuntimeResult? initialResult;

  @override
  State<AutoFixPage> createState() => _AutoFixPageState();
}

class _AutoFixPageState extends State<AutoFixPage> {
  late final TextEditingController _error = TextEditingController(
    text: _errorTextFrom(widget.initialResult),
  );
  final TextEditingController _code = TextEditingController();
  final TextEditingController _filePath = TextEditingController();

  List<ModelConfig> _models = <ModelConfig>[];
  String _modelId = '';

  ErrorAnalysis? _analysis;
  AutoFixResult? _fixResult;
  RuntimeResult? _applyResult;

  bool _analyzing = false;
  bool _generating = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _error.dispose();
    _code.dispose();
    _filePath.dispose();
    super.dispose();
  }

  static String _errorTextFrom(RuntimeResult? result) {
    if (result == null) return '';
    return <String>[
      if (result.stderr.isNotEmpty) result.stderr,
      if (result.stdout.isNotEmpty) result.stdout,
      if (result.errorSummary != null && result.errorSummary!.isNotEmpty)
        result.errorSummary!,
    ].join('\n');
  }

  Future<void> _loadModels() async {
    final models = await AppStorage.loadModels();
    final activeId = await AppStorage.activeModelId();
    if (!mounted) return;
    setState(() {
      _models = models;
      _modelId = (activeId != null && models.any((m) => m.id == activeId))
          ? activeId
          : (models.isEmpty ? '' : models.first.id);
    });
  }

  ModelConfig? get _selectedModel {
    for (final m in _models) {
      if (m.id == _modelId) return m;
    }
    return _models.isEmpty ? null : _models.first;
  }

  Future<void> _analyze() async {
    final analysis = ErrorAnalyzer.analyzeText(
      _error.text,
      fallback: widget.initialResult?.errorSummary,
    );
    dev.log(
      '分析错误 category=${analysis.category} fileRefs=${analysis.fileRefs.length}',
      name: 'AutoFix',
    );
    setState(() {
      _analyzing = true;
      _analysis = null;
    });
    // 静态分析极快，短暂延迟以产生可感知的加载态。
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() {
      _analysis = analysis;
      _analyzing = false;
    });
  }

  Future<void> _readFile() async {
    final path = _filePath.text.trim();
    if (path.isEmpty) {
      _snack('请先填写文件路径');
      return;
    }
    final r = await TermuxBridge.execute(command: 'cat "$path"', useTermux: true);
    if (!mounted) return;
    if (r.success && r.stdout.isNotEmpty) {
      setState(() => _code.text = r.stdout);
      dev.log('读取文件成功 path=$path size=${r.stdout.length}字符', name: 'AutoFix');
    } else {
      _snack('读取失败：${r.stderr.isEmpty ? 'exit ${r.exitCode}' : r.stderr}');
      dev.log('读取文件失败 path=$path stderr=${r.stderr}', name: 'AutoFix');
    }
  }

  Future<void> _generate() async {
    final model = _selectedModel;
    final analysis = _analysis;
    if (model == null) {
      _snack('请先在设置中配置模型');
      return;
    }
    if (_error.text.trim().isEmpty) {
      _snack('请先填写错误信息');
      return;
    }
    setState(() {
      _generating = true;
      _fixResult = null;
    });
    final effectiveAnalysis = analysis ?? ErrorAnalyzer.analyzeText(_error.text);
    final result = await const AutoFixer().propose(
      model: model,
      analysis: effectiveAnalysis,
      codeContext: _code.text,
    );
    if (!mounted) return;
    setState(() {
      _fixResult = result;
      _generating = false;
    });
    if (!result.success) _snack('修复生成失败：${result.error}');
  }

  Future<void> _apply() async {
    final fix = _fixResult;
    if (fix == null || !fix.hasFix) {
      _snack('暂无可用修复代码');
      return;
    }
    final path = _filePath.text.trim();
    if (path.isEmpty) {
      _snack('请填写目标文件路径');
      return;
    }
    // 写文件属高危操作，必须二次确认。
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('危险操作确认'),
        content: Text('即将覆盖文件：\n$path\n\n此操作不可撤销，是否继续？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('覆盖'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _applying = true;
      _applyResult = null;
    });
    final result = await const AutoFixer().apply(
      filePath: path,
      fixedCode: fix.fixedCode,
    );
    if (!mounted) return;
    setState(() {
      _applyResult = result;
      _applying = false;
    });
    _snack(result.success ? '已写回文件' : '写回失败：${result.errorSummary}');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自动修复')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildInputCard(),
          const SizedBox(height: 16),
          if (_analysis != null) ...<Widget>[
            _buildAnalysisCard(_analysis!),
            const SizedBox(height: 16),
          ],
          if (_fixResult != null) ...<Widget>[
            _buildFixCard(_fixResult!),
            const SizedBox(height: 16),
          ],
          if (_applyResult != null) ...<Widget>[
            _buildApplyCard(_applyResult!),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return _Card(
      title: '输入',
      icon: Icons.input_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _modelDropdown(),
          const SizedBox(height: 12),
          TextField(
            controller: _error,
            maxLines: 6,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textPrimary),
            decoration: _inputDecoration('错误信息 / 日志', '粘贴运行或测试的错误输出'),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _filePath,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.textPrimary),
                  decoration: _inputDecoration('目标文件路径', '/data/data/com.termux/files/home/main.py'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '从文件读取内容',
                onPressed: _readFile,
                icon: const Icon(Icons.file_open_outlined, color: AppColors.primaryLight),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            maxLines: 6,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textPrimary),
            decoration: _inputDecoration('代码上下文（可选）', '粘贴出错代码，或点右侧按钮从文件读取'),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _analyzing ? null : _analyze,
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  label: Text(_analyzing ? '分析中…' : '分析错误'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: Text(_generating ? '生成中…' : '生成修复'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modelDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _modelId.isEmpty ? null : _modelId,
      dropdownColor: AppColors.surfaceLight,
      decoration: _inputDecoration('修复模型', ''),
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      items: _models
          .map((m) => DropdownMenuItem<String>(
                value: m.id,
                child: Text('${m.name} · ${m.model}'),
              ))
          .toList(),
      onChanged: (String? v) => setState(() => _modelId = v ?? ''),
    );
  }

  Widget _buildAnalysisCard(ErrorAnalysis analysis) {
    return _Card(
      title: '错误分析',
      icon: Icons.analytics_outlined,
      iconColor: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _infoRow('类别', analysis.category),
          const SizedBox(height: 6),
          _infoRow('摘要', analysis.summary),
          if (analysis.fileRefs.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            _infoRow('涉及位置', analysis.fileRefs.join('、')),
          ],
        ],
      ),
    );
  }

  Widget _buildFixCard(AutoFixResult fix) {
    return _Card(
      title: fix.success ? '修复结果' : '修复未生成',
      icon: fix.success ? Icons.auto_fix_high : Icons.error_outline,
      iconColor: fix.success ? AppColors.success : AppColors.danger,
      child: fix.success
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (fix.explanation.isNotEmpty) ...<Widget>[
                  Text(fix.explanation,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                ],
                if (fix.hasFix) ...<Widget>[
                  _block(fix.fixedCode, AppColors.textSecondary),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _applying ? null : _apply,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(_applying ? '写回中…' : '应用到文件'),
                  ),
                ] else
                  const Text('模型未能生成可用的修复代码。',
                      style: TextStyle(fontSize: 13, color: AppColors.warning)),
              ],
            )
          : Text(fix.error ?? '未知错误',
              style: const TextStyle(fontSize: 13, color: AppColors.danger)),
    );
  }

  Widget _buildApplyCard(RuntimeResult result) {
    return _Card(
      title: result.success ? '写回成功' : '写回失败',
      icon: result.success ? Icons.check_circle_outline : Icons.error_outline,
      iconColor: result.success ? AppColors.success : AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('runtime: ${result.runtime} · exit: ${result.exitCode ?? '-'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (result.stderr.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _block(result.stderr, AppColors.danger),
          ],
          if (result.errorSummary != null && result.errorSummary!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('摘要：${result.errorSummary}',
                  style: const TextStyle(fontSize: 12, color: AppColors.warning)),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
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

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      hintText: hint.isEmpty ? null : hint,
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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

  Widget _block(String text, Color color) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
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

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
  });

  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget child;

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
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}