import 'package:flutter/material.dart';

/// AI Nexus 设计 token
/// 严格对照 docs/AI-Nexus-UI设计稿.html
/// 极简白 · 扁平无渐变 · 主色 #00C896 · 375×812 竖屏

class AppColors {
  AppColors._();

  static const Color white = Color(0xFFFFFFFF); // 背景
  static const Color card = Color(0xFFF7F7F7); // 分组卡片底色
  static const Color card2 = Color(0xFFF0F0F2); // 隔断
  static const Color teal = Color(0xFF00C896); // 主色：发送按钮/选中态/引擎状态点/强调
  static const Color text = Color(0xFF1A1A1A); // 主文字
  static const Color text2 = Color(0xFF8E8E93); // 次文字
  static const Color text3 = Color(0xFFC7C7CC); // 占位
  static const Color divider = Color(0xFFEFEFF1); // 分隔线
  static const Color border = Color(0xFFECECEC); // 输入框边框
  static const Color red = Color(0xFFF5576C); // 配置失败
  static const Color blue = Color(0xFF007AFF); // 「去配置」链接
  static const Color amber = Color(0xFFF5A623); // 警告

  // 终端深色界面
  static const Color termBg = Color(0xFF0C0C0E); // 终端背景
  static const Color termHead = Color(0xFF151517); // 终端顶栏
  static const Color termText = Color(0xFFD5D7DA); // 终端正文
  static const Color termOut = Color(0xFF9AA0A6); // 命令输出
  static const Color termDir = Color(0xFF6E9BF5); // 目录高亮
  static const Color termUser = Color(0xFFD5D7DA); // 用户名
}

/// 圆角：输入框/卡片 16px · 按钮 12px · 弹出面板顶部 20px · 胶囊 999px
class AppRadius {
  AppRadius._();

  static const double card = 16;
  static const double button = 12;
  static const double sheet = 20;
  static const double pill = 999;
  static const double drawer = 46; // 侧边栏右侧圆角 / 手机外壳
}

/// 字号：标题 17px 加粗 · 正文 15px · 小字 13px
class AppFontSize {
  AppFontSize._();

  static const double title = 17;
  static const double body = 15;
  static const double small = 13;
  static const double tiny = 12;
}

/// 阴影：卡片 0 2px 8px rgba(0,0,0,.06)
class AppShadow {
  AppShadow._();

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  // 侧边栏 8px 右
  static const List<BoxShadow> drawer = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 24,
      offset: Offset(8, 0),
    ),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.white,
        colorScheme: const ColorScheme.light(
          primary: AppColors.teal,
          onPrimary: AppColors.white,
          surface: AppColors.white,
          onSurface: AppColors.text,
          secondary: AppColors.teal,
          onSecondary: AppColors.white,
          error: AppColors.red,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.text,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.text,
            fontSize: AppFontSize.title,
            fontWeight: FontWeight.w700,
          ),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: AppFontSize.title,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
          bodyLarge: TextStyle(fontSize: AppFontSize.body, color: AppColors.text),
          bodyMedium: TextStyle(fontSize: AppFontSize.small, color: AppColors.text),
          bodySmall: TextStyle(fontSize: AppFontSize.tiny, color: AppColors.text2),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),
        listTileTheme: const ListTileThemeData(
          textColor: AppColors.text,
          iconColor: AppColors.text,
        ),
        // 弹出面板 / 底部弹窗
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
          ),
        ),
      );
}
