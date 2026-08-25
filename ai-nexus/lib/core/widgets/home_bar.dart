import 'package:flutter/material.dart';

/// Home Bar：高 32px，底部横条 134×5px 圆角 3px（对齐 UI 设计稿）
class HomeBar extends StatelessWidget {
  const HomeBar({super.key, this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: 134,
        height: 5,
        decoration: BoxDecoration(
          color: dark ? Colors.white.withOpacity(0.28) : Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
