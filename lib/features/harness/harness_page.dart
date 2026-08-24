import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../runtime/deepseek_harness_adapter.dart';
import '../../runtime/http_deepseek_harness_adapter.dart';
import '../../runtime/runtime_result.dart';

/// DeepSeek Harness 页面：连接独立 Harness 服务并远程执行代码 / 测试。
///
/// Harness 是独立运行的执行服务（本地或远程），本页通过 HTTP Adapter 与之通信：
/// 探测 → 连接 → 运行代码 / 测试 → 断开。所有结果均来自真实服务返回，绝不伪造。
class DeepSeekHarnessPage extends StatefulWidget {
  const DeepSeekHarnessPage({super.key});

  @override
  State<DeepSeekHarnessPage> createState() => _DeepSeekHarnessPageState();
}

class _DeepSeekHarnessPageState extends State<DeepSeekHarnessPage> {
  final TextEditingController _baseUrl =
      TextEditingController(text: 'http://127.0.0.1:8765');
  final TextEditingController _apiKey = TextEditingController();
  final TextEditingController _workspace = TextEditingController(
    text: '/data/data/com.termux/files/home',
  );
  final TextEditingController _code = TextEditingController();
  final TextEditingController _testCommand = TextEditingController(text: 'pytest -q');

  String _language = 'python';

  HarnessDetectResult? _detectResult;
  HarnessSession? _session;
  RuntimeResult? _result;

  bool _loading = false;
  String? _action;

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _workspace.dispose();
    _code.dispose();
    _testCommand.dispose();
    super.dispose();
  }

  DeepSeekHarnessAdapter _adapter() => HttpDeepSeekHarnessAdapter(
        baseUrl: _baseUrl.text.trim().isEmpty
            ? 'http://127.0.0.1:8765'
            : _baseUrl.text.trim(),
      );

  Future<void> _detect() async {
    setState(() {
      _loading = true;
      _action = 'detect';
    });
    try {
      final result = await _adapter().detect();
      if (!mounted) return;
      setState(() => _detectResult = result);
    } catch (e) {
      _snack('探测失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _action = 'connect';
    });
    try {
      final session = await _adapter().connect(
        apiKey: _apiKey.text.trim(),
        workspace: _workspace.text.trim(),
      );
      if (!mounted) return;
      setState(() => _session = session);
      _snack('已连接：session ${session.sessionId}');
    } catch (e) {
      _snack('连接失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run() async {
    final session = _session;
    if (session == null) {
      _snack('请先连接 Harness');
      return;
    }
    setState(() {
      _loading = true;
      _action = 'run';
      _result = null;
    });
    try {
      final result = await _adapter().run(
        sessionId: session.sessionId,
        code: _code.text,
        language: _language,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = _errorResult('run', e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _test() async {
    final session = _session;
    if (session == null) {
      _snack('请先连接 Harness');
      return;
    }
    setState(() {
      _loading = true;
      _action = 'test';
      _result = null;
    });
    try {
      final result = await _adapter().test(
        sessionId: session.sessionId,
        testCommand: _testCommand.text.trim(),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = _errorResult('test', e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disconnect() async {
    final session = _session;
    if (session == null) return;
    setState(() {
      _loading = true;
      _action = 'disconnect';
    });
    try {
      await _adapter().disconnect(session.sessionId);
      if (!mounted) return;
      setState(() => _session = null);
      _snack('已断开会话');
    } catch (e) {
      _snack('断开失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static RuntimeResult _errorResult(String action, Object e) => RuntimeResult(
        success: false,
        runtime: 'deepseek-harness',
        command: action,
        stderr: e.toString(),
        errorSummary: e.toString(),
      );

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DeepSeek Harness')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildConnectCard(),
          const SizedBox(height: 16),
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildExecuteCard(),
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
          _field(_baseUrl, label: 'Harness 服务地址', hint: 'http://127.0.0.1:8765'),
          const SizedBox(height: 12),
          _field(_apiKey, label: 'API Key', hint: '可选，服务端需要时填写', obscure: true),
          const SizedBox(height: 12),
          _field(_workspace, label: '工作目录', hint: '远程工作目录'),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _detect,
                  icon: const Icon(Icons.radar, size: 18),
                  label: Text(_loading && _action == 'detect' ? '探测中…' : '探测'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _connect,
                  icon: const Icon(Icons.login, size: 18),
                  label: Text(_loading && _action == 'connect' ? '连接中…' : '连接'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final detect = _detectResult;
    final session = _session;
    return _Card(
      title: '状态',
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (detect == null)
            const Text('尚未探测。点击「探测」检查 Harness 服务是否可用。',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
          else if (!detect.available)
            Text('不可用：${detect.message ?? ''}',
                style: const TextStyle(fontSize: 13, color: AppColors.danger))
          else if (!detect.compatible)
            Text('版本不兼容：${detect.message ?? ''}',
                style: const TextStyle(fontSize: 13, color: AppColors.warning))
          else
            Text('已就绪 · API v${detect.version}',
                style: const TextStyle(fontSize: 13, color: AppColors.success)),
          if (session != null) ...<Widget>[
            const SizedBox(height: 8),
            Text('会话：${session.sessionId} · ${session.workspace}',
                style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AppColors.accent)),
          ],
        ],
      ),
    );
  }

  Widget _buildExecuteCard() {
    return _Card(
      title: '执行',
      icon: Icons.terminal_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('语言', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              _LanguageDropdown(
                value: _language,
                onChanged: (String v) => setState(() => _language = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            maxLines: 6,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.textPrimary),
            decoration: _inputDecoration('要运行的代码', 'print("hello from deepseek harness")'),
          ),
          const SizedBox(height: 12),
          _field(_testCommand, label: '测试命令', hint: 'pytest -q'),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_loading || _session == null) ? null : _run,
                  icon: const Icon(Icons.play_arrow_outlined, size: 18),
                  label: Text(_loading && _action == 'run' ? '运行中…' : '▶ 运行'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_loading || _session == null) ? null : _test,
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: Text(_loading && _action == 'test' ? '测试中…' : '🧪 测试'),
                ),
              ),
            ],
          ),
          if (_session != null) ...<Widget>[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _loading ? null : _disconnect,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('断开连接'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(RuntimeResult result) {
    return _Card(
      title: result.success ? '执行成功' : '执行失败',
      icon: result.success ? Icons.check_circle_outline : Icons.error_outline,
      iconColor: result.success ? AppColors.success : AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('runtime: ${result.runtime} · exit: ${result.exitCode ?? '-'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (result.stdout.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _block(result.stdout, AppColors.textSecondary),
          ],
          if (result.stderr.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _block(result.stderr, AppColors.danger),
          ],
          if (result.errorSummary != null && result.errorSummary!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('错误摘要：${result.errorSummary}',
                  style: const TextStyle(fontSize: 12, color: AppColors.warning)),
            ),
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

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const List<String> _langs = <String>[
    'python',
    'javascript',
    'typescript',
    'bash',
    'go',
    'rust',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: AppColors.surfaceLight,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: _langs
              .map((String l) => DropdownMenuItem<String>(
                    value: l,
                    child: Text(l),
                  ))
              .toList(),
          onChanged: (String? v) {
            if (v != null) onChanged(v);
          },
        ),
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