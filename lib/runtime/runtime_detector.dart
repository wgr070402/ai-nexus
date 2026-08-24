import 'runtime_adapter.dart';

/// 项目类型识别器：根据文件特征（关键清单文件 + 扩展名）识别
/// 语言 / 项目类型 / 推荐运行时。纯静态识别，不执行任何命令。
class RuntimeDetector {
  const RuntimeDetector._();

  /// [files] 为项目文件/目录的路径列表（相对或绝对均可，内部统一归一化）。
  static RuntimeDetectResult detect(List<String> files) {
    final paths = files
        .map((f) => f.replaceAll('\\', '/').toLowerCase())
        .toSet();

    bool has(String name) =>
        paths.any((f) => f == name || f.endsWith('/$name'));

    // 关键清单文件优先
    if (has('package.json')) {
      return const RuntimeDetectResult(
          language: 'javascript', projectType: 'node-npm', recommendedRuntime: 'termux');
    }
    if (has('requirements.txt') || has('pyproject.toml') || has('setup.py')) {
      return const RuntimeDetectResult(
          language: 'python', projectType: 'python-pip', recommendedRuntime: 'termux');
    }
    if (has('cargo.toml')) {
      return const RuntimeDetectResult(
          language: 'rust', projectType: 'rust-cargo', recommendedRuntime: 'termux');
    }
    if (has('go.mod')) {
      return const RuntimeDetectResult(
          language: 'go', projectType: 'go-mod', recommendedRuntime: 'termux');
    }
    if (has('cmakelists.txt')) {
      return const RuntimeDetectResult(
          language: 'c/cpp', projectType: 'cmake', recommendedRuntime: 'termux');
    }
    if (has('makefile')) {
      return const RuntimeDetectResult(
          language: 'c/cpp', projectType: 'make', recommendedRuntime: 'termux');
    }
    if (has('pom.xml')) {
      return const RuntimeDetectResult(
          language: 'java', projectType: 'maven', recommendedRuntime: 'remote');
    }
    if (has('build.gradle') || has('build.gradle.kts')) {
      return const RuntimeDetectResult(
          language: 'java/kotlin', projectType: 'gradle', recommendedRuntime: 'remote');
    }

    // 扩展名兜底
    final exts = <String>{};
    for (final f in paths) {
      final i = f.lastIndexOf('.');
      if (i > 0) exts.add(f.substring(i));
    }

    if (exts.contains('.py')) {
      return const RuntimeDetectResult(
          language: 'python', projectType: 'python-script', recommendedRuntime: 'termux');
    }
    if (exts.contains('.ts')) {
      return const RuntimeDetectResult(
          language: 'typescript', projectType: 'node-script', recommendedRuntime: 'termux');
    }
    if (exts.contains('.js')) {
      return const RuntimeDetectResult(
          language: 'javascript', projectType: 'node-script', recommendedRuntime: 'termux');
    }
    if (exts.contains('.c') || exts.contains('.cpp') || exts.contains('.h') || exts.contains('.hpp')) {
      return const RuntimeDetectResult(
          language: 'c/cpp', projectType: 'native', recommendedRuntime: 'termux');
    }
    if (exts.contains('.rs')) {
      return const RuntimeDetectResult(
          language: 'rust', projectType: 'rust-script', recommendedRuntime: 'termux');
    }
    if (exts.contains('.go')) {
      return const RuntimeDetectResult(
          language: 'go', projectType: 'go-script', recommendedRuntime: 'termux');
    }

    return const RuntimeDetectResult(
        language: 'unknown', projectType: 'unknown', recommendedRuntime: '');
  }
}