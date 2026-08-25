import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// 设置分组容器：#F7F7F7 圆角 16px 带阴影
class SettingGroup extends StatelessWidget {
  const SettingGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadow.card,
      ),
      child: Column(children: children),
    );
  }
}

/// 设置行（label + value + chevron）
class SettingRow extends StatelessWidget {
  const SettingRow({super.key, required this.label, this.value, this.trailing});

  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFECECEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: AppFontSize.body, color: AppColors.text),
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: const TextStyle(fontSize: 14, color: AppColors.text2),
            ),
          if (trailing != null)
            trailing!
          else
            const Icon(Icons.chevron_right, size: 18, color: AppColors.text3),
        ],
      ),
    );
  }
}

/// 单选行（dot + label + hint，选中态青绿）
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.label,
    this.hint,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFECECEE))),
        ),
        child: Row(
          children: [
            // 圆点
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.teal : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.teal : AppColors.text3,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: AppColors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: AppFontSize.body,
                  color: AppColors.text,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (hint != null)
              Text(
                hint!,
                style: const TextStyle(fontSize: AppFontSize.tiny, color: AppColors.text3),
              ),
          ],
        ),
      ),
    );
  }
}

/// 开关行（label + 开关）
class SwitchRow extends StatefulWidget {
  const SwitchRow({super.key, required this.label, this.value = false});

  final String label;
  final bool value;

  @override
  State<SwitchRow> createState() => _SwitchRowState();
}

class _SwitchRowState extends State<SwitchRow> {
  late bool _v = widget.value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFECECEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: const TextStyle(fontSize: AppFontSize.body, color: AppColors.text),
            ),
          ),
          Switch(
            value: _v,
            activeTrackColor: AppColors.teal,
            onChanged: (v) => setState(() => _v = v),
          ),
        ],
      ),
    );
  }
}
