import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// 聊天输入栏（复用组件）
/// 三态：空态（发送灰）· 有内容（发送青绿）· 加号弹出菜单
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    this.placeholder = '发消息或按住说话',
    this.showModelChip = true,
    this.showVoice = true,
    this.onSend,
  });

  final String placeholder;
  final bool showModelChip;
  final bool showVoice;
  final void Function(String text)? onSend;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 加号弹出菜单
  void _openSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (context) => const _PlusSheet(),
    );
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadow.card,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            if (widget.showVoice)
              _circleBtn(
                icon: Icons.graphic_eq,
                onTap: () {},
              ),
            if (widget.showModelChip) ...[
              const SizedBox(width: 4),
              _modelChip(),
            ],
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: AppFontSize.body, color: AppColors.text),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: widget.placeholder,
                  hintStyle: const TextStyle(color: AppColors.text3, fontSize: AppFontSize.body),
                ),
              ),
            ),
            _circleBtn(icon: Icons.add, onTap: _openSheet),
            const SizedBox(width: 4),
            _sendBtn(enabled: hasText, onSend: _handleSend),
          ],
        ),
      ),
    );
  }

  Widget _modelChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Auto',
            style: TextStyle(
              fontSize: AppFontSize.small,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          SizedBox(width: 3),
          Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.text2),
        ],
      ),
    );
  }

  Widget _circleBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(icon, size: 22, color: AppColors.text),
      ),
    );
  }

  Widget _sendBtn({required bool enabled, required VoidCallback onSend}) {
    return InkWell(
      onTap: enabled ? onSend : null,
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? AppColors.teal : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.send,
          size: 20,
          color: enabled ? AppColors.white : AppColors.text3,
        ),
      ),
    );
  }
}

/// 加号弹出菜单：拍照 · 照片视频 · 手机文件 + 技能 Skill · 专家中心
class _PlusSheet extends StatelessWidget {
  const _PlusSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 抓取条
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFE4E4E6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 三大按钮
          Row(
            children: const [
              _BigBtn(icon: Icons.camera_alt_outlined, label: '拍照'),
              SizedBox(width: 12),
              _BigBtn(icon: Icons.photo_outlined, label: '照片 / 视频'),
              SizedBox(width: 12),
              _BigBtn(icon: Icons.insert_drive_file_outlined, label: '手机文件'),
            ],
          ),
          const SizedBox(height: 16),
          const _SheetRow(icon: Icons.auto_awesome_outlined, label: '技能 Skill'),
          const _SheetRow(icon: Icons.person_outline, label: '专家中心'),
        ],
      ),
    );
  }
}

class _BigBtn extends StatelessWidget {
  const _BigBtn({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: AppColors.text),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppFontSize.small,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF2F2F4))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.text),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: AppFontSize.body, color: AppColors.text),
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.text3),
        ],
      ),
    );
  }
}
