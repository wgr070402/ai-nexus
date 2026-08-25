import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../settings/settings_page.dart';
import '../terminal/terminal_page.dart';
import '../chat/chat_page.dart';

/// 首页壳：底部导航 5 Tab（聊天 / 群聊 / 终端 / 项目 / 设置），默认选中聊天
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    ChatPage(),
    _PlaceholderTab(title: '群聊', hint: '群聊模块开发中（M3）'),
    TerminalPage(),
    _PlaceholderTab(title: '项目', hint: '项目管理开发中'),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.teal.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: AppColors.teal),
            label: '聊天',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups, color: AppColors.teal),
            label: '群聊',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal),
            selectedIcon: Icon(Icons.terminal, color: AppColors.teal),
            label: '终端',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder, color: AppColors.teal),
            label: '项目',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.teal),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: const TextStyle(fontSize: AppFontSize.small, color: AppColors.text2),
            ),
          ],
        ),
      ),
    );
  }
}
