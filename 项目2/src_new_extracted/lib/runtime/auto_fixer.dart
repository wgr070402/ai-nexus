import 'dart:convert';
import 'dart:developer' as dev;

import '../core/models/chat_models.dart';
import '../core/services/llm_service.dart';
import '../services/termux_bridge.dart';
import 'error_analyzer.dart';
import 'runtime_result.dart';

/// 自动修复结果（由 LLM 生成）。
class AutoFixResult {
  const AutoFixResult({
    required this.success,
    this.explanation = '',
    this.fixedCode = '',
    this.model = '',
    this.error,
  });

  final bool success;

  /// 错误原因与修复思路（Markdown）。
  final String explanation;

  /// 修复后的完整代码。
  final String fixedCode;

  final String model;
  final String? error;

  bool get hasFix => fixedCode.trim().isNotEmpty;

  factory AutoFixResult.failure(String error) =>
      AutoFixResult(success: false, error: error);
}

/// 自动修复器：错误分析 + LLM 生成修复 + 写回文件。
///
/// - [propose] 用 LLM 生成修复代码（真实调用，绝不伪造）；
/// - [apply] 通过 Termux `base64` 安全写回目标文件（写文件属高危操作，需 UI 二次确认）。
class AutoFixer {
  const AutoFixer();

  /// 依据错误分析与代码上下文，让模型给出修复。
  Future<AutoFixResult> propose({
    required ModelConfig model,
    required ErrorAnalysis analysis,
    required String codeContext,
  }) async {
    final prompt = _buildPrompt(analysis, codeContext);
    final messages = <ChatMessage>[
      ChatMessage(
        id: 'sys-autofix',
        role: ChatRole.system,
        content: '你是一名资深软件工程师，擅长定位编译/运行错误并给出可落地的修复。'
            '请始终用简洁中文说明原因与思路，修复代码必须完整可运行。'
            '若信息不足无法修复，请明确说明，不要编造代码。',
      ),
      ChatMessage(id: 'usr-autofix', role: ChatRole.user, content: prompt),
    ];

    final buffer = StringBuffer();
    try {
      await for (final delta
          in const LlmService().streamChat(model: model, messages: messages)) {
        buffer.write(delta);
      }
    } catch (e) {
      dev.log('propose 生成失败：$e', name: 'AutoFix', error: e);
      return AutoFixResult.failure(e.toString());
    }

    final text = buffer.toString();
    final parsed = _parse(text);
    dev.log(
      'propose 成功 model=${model.model} explanation=${parsed.explanation.length}字符 '
      'code=${parsed.code.length}字符',
      name: 'AutoFix',
    );
    return AutoFixResult(
      success: true,
      explanation: parsed.explanation,
      fixedCode: parsed.code,
      model: model.model,
    );
  }

  /// 将修复后代码写回 [filePath]（Termux 内绝对路径）。
  Future<RuntimeResult> apply({
    required String filePath,
    required String fixedCode,
  }) async {
    final b64 = base64.encode(utf8.encode(fixedCode));
    final command = "printf %s '$b64' | base64 -d > '$filePath'";
    dev.log(
      'apply 写回 filePath=$filePath code=${fixedCode.length}字符',
      name: 'AutoFix',
    );
    final r = await TermuxBridge.execute(command: command, useTermux: true);
    return RuntimeResult(
      success: r.success,
      runtime: r.executor,
      exitCode: r.exitCode,
      command: '写入文件 $filePath',
      stdout: r.stdout,
      stderr: r.stderr,
      errorSummary: r.success
          ? null
          : (r.stderr.trim().isEmpty ? '写入失败 exit ${r.exitCode}' : r.stderr.trim()),
      changedFiles: <String>[filePath],
    );
  }

  String _buildPrompt(ErrorAnalysis analysis, String codeContext) {
    final buffer = StringBuffer()
      ..writeln('请修复以下代码问题。')
      ..writeln()
      ..writeln('【错误类别】${analysis.category}')
      ..writeln('【错误摘要】${analysis.summary}');
    if (analysis.fileRefs.isNotEmpty) {
      buffer.writeln('【涉及位置】${analysis.fileRefs.join('、')}');
    }
    buffer
      ..writeln()
      ..writeln('【现有代码】（若为空请根据错误推断）')
      ..writeln('```')
      ..writeln(codeContext.trim().isEmpty ? '（未提供）' : codeContext.trim())
      ..writeln('```')
      ..writeln()
      ..writeln('输出要求：')
      ..writeln('1. 先简要说明错误原因与修复思路；')
      ..writeln('2. 再给出完整可运行的修复后代码，放入一个 ``` 代码块中；')
      ..writeln('3. 无法修复时明确说明，不要给代码。');
    return buffer.toString();
  }

  static _ParsedFix _parse(String text) {
    final fence = RegExp(r'```[^\n]*\n([\s\S]*?)\n```');
    final matches = fence.allMatches(text).toList();
    String code = '';
    for (final m in matches) {
      final c = (m.group(1) ?? '').trimRight();
      if (c.length > code.length) code = c;
    }
    String explanation = text.replaceAll(fence, '').trim();
    if (explanation.isEmpty) explanation = '（已生成修复代码）';
    return _ParsedFix(explanation, code);
  }
}

class _ParsedFix {
  _ParsedFix(this.explanation, this.code);
  final String explanation;
  final String code;
}