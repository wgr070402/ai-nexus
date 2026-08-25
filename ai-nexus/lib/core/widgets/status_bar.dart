import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// 状态栏：高 48px，左时间，右信号/电量（对齐 UI 设计稿）
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, this.dark = false, this.time = '9:41'});

  final bool dark; // 终端深色界面用
  final String time;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : AppColors.text;
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 24, right: 24, top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            time,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.signal_cellular_alt, size: 14, color: color),
              const SizedBox(width: 5),
              Icon(Icons.battery_full, size: 18, color: color),
            ],
          ),
        ],
      ),
    );
  }
}
