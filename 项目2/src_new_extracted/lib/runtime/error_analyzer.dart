import 'runtime_result.dart';

/// 错误分类标签。
class ErrorCategory {
  ErrorCategory._();

  static const String missingDependency = '依赖缺失';
  static const String compileError = '编译错误';
  static const String testFailure = '测试失败';
  static const String permissionError = '权限不足';
  static const String runtimeError = '运行错误';
  static const String unknown = '未知错误';
}

/// 错误分析结果：类别 + 摘要 + 涉及文件/位置。
class ErrorAnalysis {
  const ErrorAnalysis({
    required this.category,
    required this.summary,
    this.fileRefs = const <String>[],
  });

  final String category;
  final String summary;

  /// 从日志中提取的「文件:行号」引用。
  final List<String> fileRefs;
}

/// 错误分析器：从 [RuntimeResult] 或原始文本中静态提取错误信息。
class ErrorAnalyzer {
  const ErrorAnalyzer._();

  static ErrorAnalysis analyze(RuntimeResult result) {
    final raw = <String>[
      if (result.stderr.isNotEmpty) result.stderr,
      if (result.stdout.isNotEmpty) result.stdout,
      if (result.errorSummary != null && result.errorSummary!.isNotEmpty)
        result.errorSummary!,
    ].join('\n');
    return analyzeText(raw, fallback: result.errorSummary);
  }

  /// 从一段原始错误文本中分析。
  static ErrorAnalysis analyzeText(String raw, {String? fallback}) {
    final text = raw.trim().isEmpty ? (fallback ?? '') : raw;
    final category = _categorize(text);
    final fileRefs = _extractFileRefs(text);
    final summary = _firstLine(text);
    return ErrorAnalysis(
      category: category,
      summary: summary.isEmpty ? '（无可用错误信息）' : summary,
      fileRefs: fileRefs,
    );
  }

  static String _categorize(String text) {
    final lower = text.toLowerCase();

    if (_containsAny(lower, const <String>[
      'permission denied',
      'access denied',
      'operation not permitted',
      'read-only',
      'eacces',
    ])) {
      return ErrorCategory.permissionError;
    }

    if (_containsAny(lower, const <String>[
      'command not found',
      'no such file or directory',
      'module not found',
      'modulenotfounderror',
      'importerror',
      'cannot find module',
      'is not installed',
      'no module named',
      'cannot find package',
      'unresolved import',
      'not recognized',
    ])) {
      return ErrorCategory.missingDependency;
    }

    if (_containsAny(lower, const <String>[
      'failed',
      'assertionerror',
      'assert',
      'tests failed',
      'test failed',
      'failures:',
      'error: test',
    ])) {
      return ErrorCategory.testFailure;
    }

    if (_containsAny(lower, const <String>[
      'error:',
      'error：',
      'syntaxerror',
      'traceback',
      'compile',
      'compilation',
      'cannot find symbol',
      'unresolved reference',
      'typeerror',
      'nameerror',
      'referenceerror',
    ])) {
      return ErrorCategory.compileError;
    }

    if (_containsAny(lower, const <String>[
      'exception',
      'runtimeerror',
      'panic',
      'segmentation fault',
      'stack overflow',
      'fatal',
    ])) {
      return ErrorCategory.runtimeError;
    }

    return ErrorCategory.unknown;
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final n in needles) {
      if (text.contains(n)) return true;
    }
    return false;
  }

  /// 提取形如 `file.py:12`、`File ".../a.py", line 3`、`at a.ts (a.ts:5)` 的引用。
  static List<String> _extractFileRefs(String text) {
    final refs = <String>{};

    final colon = RegExp(r'([\w.\-~/]+\.(?:py|js|ts|jsx|tsx|rs|go|c|cpp|h|java|kt|dart))\s*[:：]\s*(\d+)');
    for (final m in colon.allMatches(text)) {
      refs.add('${m.group(1)}:${m.group(2)}');
    }

    final pythonTrace = RegExp(r'File "([^"]+)", line (\d+)');
    for (final m in pythonTrace.allMatches(text)) {
      refs.add('${m.group(1)}:${m.group(2)}');
    }

    final atLine = RegExp(r'\(([\w.\-~/]+\.(?:py|js|ts|jsx|tsx|rs|go|c|cpp|h|java|kt|dart)):(\d+)\)');
    for (final m in atLine.allMatches(text)) {
      refs.add('${m.group(1)}:${m.group(2)}');
    }

    return refs.toList();
  }

  static String _firstLine(String text) {
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty) {
        // 跳过 Traceback 包裹行，优先取真正的内容行。
        if (t.startsWith('Traceback') || t.startsWith('File "')) continue;
        return t.length > 300 ? '${t.substring(0, 300)}…' : t;
      }
    }
    return '';
  }
}