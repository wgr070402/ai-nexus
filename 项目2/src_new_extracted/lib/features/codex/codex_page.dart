import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../runtime/codex_adapter.dart';
import '../../runtime/http_codex_adapter.dart';

/// Codex 页面：对接 OpenAI Codex / Responses API 生成代码。
///
/// 流程：验证连接（鉴权/连通性）→ 输入任务 → 生成代码。结果均来自真实 API，绝不伪造。
class CodexPage extends StatefulWidget {
  const CodexPage({super.key});

  @override
  State<CodexPage> createState() => _CodexPageState();
}

class _CodexPageState extends State<CodexPage> {
  final TextEditingController _apiKey = TextEditingController();
  final TextEditingController _model =
      TextEditingController(text: 'gpt-4.1-mini');
  final TextEditingController _prompt = TextEditingController();

  CodexDetectResult? _detectResult;
  CodexGenerateResult? _result;

  bool _loading = false;
  String? _action;

  @override
  void dispose() {
    _apiKey.dispose();
    _model.dispose();
    _prompt.dispose();
    super.dispose();
  }

  CodexAdapter _adapter() => HttpCodexAdapter();

  Future<void> _detect() async {
    setState(() {
      _loading = true;
      _action = 'detect';
      _detectResult = null;
    });
    try {
      final result = await _adapter().detect(apiKey: _apiKey.text.trim());
      if (!mounted) return;
      setState(() => _detectResult = result);
    } catch (e) {
      dev.log('detect 异常：$e', name: 'CodexPage', error: e);
      _snack('验证失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _action = 'generate';
      _result = null;
    });
    try {
      final result = await _adapter().generate(
        apiKey: _apiKey.text.trim(),
        model: _model.text.trim().isEmpty ? 'gpt-4.1-mini' : _model.text.trim(),
        prompt: _prompt.text.trim(),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      dev.log('generate 异常：$e', name: 'CodexPage', error: e);
      if (mounted) setState(() => _result = CodexGenerateResult.failure(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
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
      appBar: AppBar(title: const Text('Codex')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildConnectCard(),
          const SizedBox(height: 16),
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildGenerateCard(),
          if (_result != null) ...<Widget>[
            const SizedBox(height: 16),
            _buildResultCard(_result!),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectCard() {
    return _Card(
      title: '连接配置',
      icon: Icons.link_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _field(_apiKey, label: 'API Key', hint: 'sk-…', obscure: true),
          const SizedBox(height: 12),
          _field(_model, label: '模型', hint: 'gpt-4.1-mini'),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loading ? null : _detect,
            icon: const Icon(Icons.radar, size: 18),
            label: Text(_loading && _action == 'detect' ? '验证中…' : '验证连接'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final detect = _detectResult;
    return _Card(
      title: '状态',
      icon: Icons.info_outline,
      child: detect == null
          ? const Text('尚未验证。点击「验证连接」检查 API Key 与连通性。',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
          : detect.available
              ? const Text('已就绪 · API Key 有效',
                  style: TextStyle(fontSize: 13, color: AppColors.success))
              : Text('不可用：${detect.message ?? ''}',
                  style: const TextStyle(fontSize: 13, color: AppColors.danger)),
    );
  }

  Widget _buildGenerateCard() {
    return _Card(
      title: '生成代码',
      icon: Icons.code_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _prompt,
            maxLines: 5,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: _inputDecoration('任务描述', '用 Python 写一个快速排序，并附测试'),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(_loading && _action == 'generate' ? '生成中…' : '生成代码'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(CodexGenerateResult result) {
    return _Card(
      title: result.success ? '生成成功' : '生成失败',
      icon: result.success ? Icons.check_circle_outline : Icons.error_outline,
      iconColor: result.success ? AppColors.success : AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (result.success) ...<Widget>[
            if (result.model.isNotEmpty)
              Text('模型：${result.model}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            _block(result.output, AppColors.textSecondary),
          ] else
            Text(result.error ?? '未知错误',
                style: const TextStyle(fontSize: 13, color: AppColors.danger)),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    required String label,
    required String hint,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      decoration: _inputDecoration(label, hint),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      hintText: hint,
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
      constraints: const BoxConstraints(maxHeight: 300),
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
  final Widget child;
  final Color? iconColor;

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