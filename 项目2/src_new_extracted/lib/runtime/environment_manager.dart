import '../services/termux_bridge.dart';

/// 单个运行时环境工具状态。
class EnvTool {
  const EnvTool({required this.name, required this.installed, this.version = ''});

  final String name;
  final bool installed;
  final String version;
}

/// 环境检测报告。
class EnvironmentReport {
  const EnvironmentReport({required this.tools, required this.executor});

  final List<EnvTool> tools;

  /// 实际执行通道：local / termux / none。
  final String executor;

  bool isInstalled(String name) => tools.any((t) => t.name == name && t.installed);

  EnvTool tool(String name) =>
      tools.firstWhere((t) => t.name == name, orElse: () => EnvTool(name: name, installed: false));
}

/// 环境管理器：探测 Python / Node / Git / C/C++ / Rust / Go 等运行时是否可用及版本。
///
/// 通过 TermuxBridge 执行 `--version` 类命令检测。Android 本地完整运行时
/// 依赖 Termux；未装 Termux 时本地 shell 缺少这些工具，将如实返回「未安装」。
class EnvironmentManager {
  const EnvironmentManager._();

  /// 待探测的运行时 -> 对应探测命令。
  static const Map<String, String> _probes = <String, String>{
    'python': 'python3 --version',
    'pip': 'pip3 --version',
    'node': 'node --version',
    'npm': 'npm --version',
    'pnpm': 'pnpm --version',
    'git': 'git --version',
    'gcc': 'gcc --version',
    'clang': 'clang --version',
    'make': 'make --version',
    'cmake': 'cmake --version',
    'cargo': 'cargo --version',
    'go': 'go version',
  };

  /// 执行全量环境探测，返回各工具安装状态与版本。
  static Future<EnvironmentReport> detect() async {
    final tools = <EnvTool>[];
    var executor = 'none';

    for (final entry in _probes.entries) {
      final result = await TermuxBridge.execute(command: entry.value, useTermux: true);
      executor = result.executor;
      tools.add(EnvTool(
        name: entry.key,
        installed: result.success,
        version: _version(result),
      ));
    }

    return EnvironmentReport(tools: tools, executor: executor);
  }

  /// 提取版本号首行（stdout 优先，回退 stderr）。
  static String _version(CommandResult result) {
    final merged = (result.stdout + result.stderr).trim();
    final line = merged.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    return line.trim();
  }
}