/// 全局常量。
class AppConstants {
  AppConstants._();

  static const String appName = 'AI Nexus';
  static const String appTagline = '个人 AI Agent 工作台';
  static const String appVersion = '0.1.0';

  /// 与 Android 原生侧（Termux 桥接等）约定的 MethodChannel 名称。
  /// 策划书约定：com.ai-nexus/termux
  static const String termuxChannel = 'com.ai-nexus/termux';
}
