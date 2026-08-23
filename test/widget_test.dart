// AI Nexus 冒烟测试：验证应用能正常构建并渲染主框架。

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_nexus/app/app.dart';

void main() {
  testWidgets('应用能正常启动并渲染底部导航', (WidgetTester tester) async {
    await tester.pumpWidget(const AiNexusApp());

    // 应用标题
    expect(find.text('AI Nexus'), findsOneWidget);

    // 底部导航五个板块标签
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('会话'), findsOneWidget);
    expect(find.text('Agent'), findsWidgets);
    expect(find.text('项目'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    // 首页快捷操作
    expect(find.text('快捷操作'), findsOneWidget);
  });

  testWidgets('切换底部导航到设置页', (WidgetTester tester) async {
    await tester.pumpWidget(const AiNexusApp());

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('版本'), findsOneWidget);
    expect(find.text('Phase 1 · 项目初始化'), findsOneWidget);
  });
}
