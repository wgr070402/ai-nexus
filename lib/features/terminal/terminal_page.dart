import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/models/terminal_models.dart';
import '../../core/services/terminal_controller.dart';
import '../../services/termux_bridge.dart';

/// 内置终端页面：在 App 内直接执行命令。
///
/// 支持：
///  - 多条终端会话（可新建/切换/删除，命令与历史持久化）；
///  - 命令历史、复制/清屏/停止；
///  - 两条执行通道：本地 shell（/system/bin/sh，默认兜底）与 Termux（Termux:API，
///    需真机安装 Termux + Termux:API，完整 Linux/CLI）。
class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  static const String _prompt = 'ai-nexus';

  final TerminalController _term = TerminalController();
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();

  int _historyIndex = -1;

  /// 当前正在执行的会话 id，供「停止」按钮终止本地 shell 进程。
  String? _currentSessionId;

  bool _busy = false;
  // 默认使用本地 shell（/system/bin/sh），在任何设备上都可靠可用；
  // 用户可手动打开 Termux 开关，走完整 Linux 环境（python/node/git 等），
  // 但 Termux 在部分国产手机上可能因系统杀后台而不稳定。
  bool _useTermux = false;
  TermuxStatus _status = const TermuxStatus(
    termux: false,
    termuxVersion: '',
    termuxApi: false,
    termuxApiVersion: '',
  );

  TermSession? get _session => _term.active;
  List<TermCommand> get _entries => _session?.commands ?? <TermCommand>[];
  List<String> get _history => _session?.history ?? <String>[];

  @override
  void initState() {
    super.initState();
    _init();
    _detectTermux();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _term.dispose();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _term.init();
    if (mounted) setState(() {});
  }

  Future<void> _detectTermux() async {
    try {
      final status = await TermuxBridge.checkInstalled();
      if (!mounted) return;
      dev.log(
        'Termux 检测 termux=${status.termux} api=${status.termuxApi} '
        '签名=${status.termuxSignatureValid} sha256=${status.termuxSha256}',
        name: 'TerminalSession',
      );
      setState(() => _status = status);
    } catch (e) {
      dev.log('Termux 检测失败：$e', name: 'TerminalSession', error: e);
    }
  }

  /// 键盘 handler：实现命令历史的上下键导航。
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!_inputFocus.hasFocus) return false;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _navigateHistory(-1);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _navigateHistory(1);
      return true;
    }
    return false;
  }

  void _navigateHistory(int direction) {
    final history = _history;
    if (history.isEmpty) return;
    if (_historyIndex == -1 && direction == 1) return;
    final next = _historyIndex + direction;
    if (next < -1 || next >= history.length) return;
    setState(() {
      _historyIndex = next;
      _input.text = next == -1 ? '' : history[history.length - 1 - next];
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    });
  }

  Future<void> _run(String command) async {
    final cmd = command.trim();
    if (cmd.isEmpty) return;

    if (cmd == 'clear' || cmd == 'cls') {
      _clear();
      return;
    }
    if (cmd == 'exit') {
      _input.clear();
      return;
    }

    final session = _session;
    if (session == null) return;

    _appendHistory(cmd);

    // 生成会话 id，供本地 shell 进程按会话终止。
    final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _currentSessionId = sessionId;
    final entry = TermCommand(
      command: cmd,
      executor: _useTermux ? 'termux' : 'local',
    );
    setState(() {
      session.commands.add(entry);
      _busy = true;
      _input.clear();
      _historyIndex = -1;
    });
    _scrollToBottom();

    try {
      final result = await TermuxBridge.execute(
        command: cmd,
        sessionId: sessionId,
        useTermux: _useTermux,
      );
      if (!mounted) return;
      setState(() {
        entry.executor = result.executor;
        entry.output = result.stdout;
        entry.error = result.stderr;
        entry.exitCode = result.exitCode;
        entry.done = true;
        _busy = false;
        _currentSessionId = null;
      });
      dev.log(
        '命令执行完成 cmd=$cmd executor=${result.executor} '
        'exitCode=${result.exitCode} stdout=${result.stdout.length}B stderr=${result.stderr.length}B',
        name: 'TerminalSession',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        entry.error = '执行异常：${e.toString()}';
        entry.done = true;
        _busy = false;
        _currentSessionId = null;
      });
      dev.log('命令执行异常 cmd=$cmd error=$e', name: 'TerminalSession', error: e);
    }
    session.updatedAt = DateTime.now();
    await _term.persist();
    _scrollToBottom();
  }

  /// 终止当前正在执行的本地 shell 进程（Termux 通道的取消需在真机按会话动作实现）。
  Future<void> _stop() async {
    final sid = _currentSessionId;
    if (sid == null || sid.isEmpty) return;
    dev.log('停止会话进程 sessionId=$sid', name: 'TerminalSession');
    await TermuxBridge.kill(sid);
  }

  void _appendHistory(String cmd) {
    final session = _session;
    if (session == null) return;
    session.history.add(cmd);
    if (session.history.length > 100) session.history.removeAt(0);
  }

  void _clear() {
    final session = _session;
    if (session == null) return;
    setState(() {
      session.commands.clear();
      _input.clear();
      _historyIndex = -1;
    });
    dev.log('清屏 会话 id=${session.id} name=${session.name}', name: 'TerminalSession');
    _term.persist();
  }

  void _copyAll() {
    final buffer = StringBuffer();
    for (final e in _entries) {
      buffer.writeln('$_prompt \$ ${e.command}');
      if (e.output.isNotEmpty) buffer.writeln(e.output);
      if (e.error.isNotEmpty) buffer.writeln(e.error);
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制全部输出到剪贴板')),
    );
  }

  void _newSession() {
    final session = _term.createSession();
    setState(() => _historyIndex = -1);
    _input.clear();
    dev.log('页面新建会话 id=${session.id}', name: 'TerminalSession');
  }

  Future<void> _deleteSession(TermSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('删除会话'),
        content: Text('确定删除「${session.name}」及其中 ${session.commands.length} 条记录吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _term.deleteSession(session.id);
      if (mounted) {
        setState(() => _historyIndex = -1);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('终端 · ${session.name}'),
        actions: <Widget>[
          IconButton(
            tooltip: '新建会话',
            onPressed: _newSession,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: '会话列表',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.view_list_outlined),
          ),
          IconButton(
            tooltip: '复制全部',
            onPressed: _copyAll,
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: '清屏',
            onPressed: _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          if (_busy)
            IconButton(
              tooltip: '停止',
              onPressed: _stop,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: <Widget>[
          _buildStatusBar(),
          const Divider(height: 1),
          Expanded(child: _buildOutput()),
          _buildInputBar(),
        ],
      ),
    );
  }

  /// 会话列表抽屉。
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text('终端会话',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _newSession();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('新建'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _term.sessions.isEmpty
                  ? const Center(
                      child: Text('暂无会话',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    )
                  : ListView.builder(
                      itemCount: _term.sessions.length,
                      itemBuilder: (BuildContext context, int index) {
                        final s = _term.sessions[index];
                        final isActive = s.id == _term.activeId;
                        return ListTile(
                          selected: isActive,
                          selectedTileColor:
                              AppColors.primary.withValues(alpha: 0.10),
                          leading: Icon(
                            Icons.terminal,
                            color: isActive
                                ? AppColors.primaryLight
                                : AppColors.textMuted,
                          ),
                          title: Text(s.name,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: isActive
                                      ? AppColors.primaryLight
                                      : AppColors.textPrimary)),
                          subtitle: Text('${s.commands.length} 条记录',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          trailing: _term.sessions.length > 1
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: AppColors.danger),
                                  onPressed: () => _deleteSession(s),
                                )
                              : null,
                          onTap: () {
                            _term.switchSession(s.id);
                            setState(() => _historyIndex = -1);
                            _input.clear();
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部的后端状态条：显示 Termux 可用性 + 签名校验结果，并允许切换执行通道。
  Widget _buildStatusBar() {
    final String label;
    final bool trusted;
    if (!_status.termux) {
      label = '未检测到 Termux，当前使用本地 shell';
      trusted = false;
    } else if (!_status.termuxSignatureValid) {
      label = 'Termux ${_status.termuxVersion} 签名校验失败（已回退本地 shell）';
      trusted = false;
    } else if (_status.termuxApi) {
      label = 'Termux ${_status.termuxVersion} · API ${_status.termuxApiVersion} · 签名 OK';
      trusted = true;
    } else {
      label = 'Termux ${_status.termuxVersion} · 签名 OK（Termux:API 未装）';
      trusted = true;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(
        children: <Widget>[
          _StatusDot(value: trusted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Text('Termux',
              style: TextStyle(
                  fontSize: 12,
                  color: _useTermux ? AppColors.primaryLight : AppColors.textMuted)),
          Switch.adaptive(
            value: _useTermux,
            activeTrackColor: AppColors.primary,
            onChanged: (bool v) => setState(() => _useTermux = v),
          ),
        ],
      ),
    );
  }

  /// 输出区域。
  Widget _buildOutput() {
    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.terminal, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text('这是 App 内置终端',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('在下方向终端输入命令，例如：echo hello',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _entries.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildEntry(_entries[index]);
      },
    );
  }

  Widget _buildEntry(TermCommand entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('$_prompt ',
                  style: const TextStyle(
                      color: AppColors.success,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Expanded(
                child: Text(entry.command,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'monospace',
                        fontSize: 13)),
              ),
              Text('[${entry.executor}]',
                  style: TextStyle(
                      fontSize: 10,
                      color: entry.executor == 'termux'
                          ? AppColors.accent
                          : AppColors.textMuted)),
            ],
          ),
          if (entry.output.isNotEmpty)
            _MonospaceText(text: entry.output, color: AppColors.textSecondary),
          if (entry.error.isNotEmpty)
            _MonospaceText(text: entry.error, color: AppColors.danger),
          if (entry.done && entry.exitCode != null && entry.exitCode != 0)
            Text('exit: ${entry.exitCode}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  /// 底部输入区。
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text('$_prompt ',
                style: const TextStyle(
                    color: AppColors.success,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _inputFocus,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 14),
                cursorColor: AppColors.primaryLight,
                textInputAction: TextInputAction.send,
                onSubmitted: _run,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _busy ? '正在执行…' : '输入命令，回车执行',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: '执行',
              onPressed: _busy ? null : () => _run(_input.text),
              icon: const Icon(Icons.send, color: AppColors.primaryLight),
            ),
          ],
        ),
      ),
    );
  }
}

/// 状态圆点。
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    final Color color = value ? AppColors.success : AppColors.warning;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 等宽字体文本（保留换行与空格）。
class _MonospaceText extends StatelessWidget {
  const _MonospaceText({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontFamily: 'monospace', fontSize: 13, height: 1.4),
      ),
    );
  }
}