// AI Nexus 冒烟测试：验证 App 能正常构建并渲染首屏导航与单聊空态。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_nexus/app/app.dart';

void main() {
  testWidgets('AiNexusApp 能正常构建并渲染底部导航与首页空态', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AiNexusApp()));
    // 触发首帧并推进 go_router 初始路由（不用 pumpAndSettle：终端页有无限循环光标动画）
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 底部导航各 Tab 应存在
    expect(find.text('聊天'), findsWidgets);
    expect(find.text('终端'), findsWidgets);
    expect(find.text('设置'), findsWidgets);

    // 首页默认进入单聊空态文案
    expect(find.text('内容由 AI 生成'), findsOneWidget);
  });
}