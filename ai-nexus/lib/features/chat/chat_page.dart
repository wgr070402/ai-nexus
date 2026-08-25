import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../core/models/chat_models.dart';
import '../../core/models/model_config.dart';
import '../../core/widgets/chat_bubble.dart';
import '../../core/widgets/home_bar.dart';
import '../../core/widgets/status_bar.dart';
import '../home/widgets/app_drawer.dart';
import '../home/widgets/composer.dart';
import 'providers/chat_provider.dart';

/// 单聊界面（聊天 Tab）：流式输出 + 顶部模型切换 + 流式中切模型
class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.white,
      drawer: const AppDrawer(),
      body: Builder(
        builder: (context) => Column(
          children: [
            const StatusBar(),
            // 顶部：汉堡键 + 模型选择器
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Scaffold.of(context).openDrawer(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        boxShadow: AppShadow.card,
                      ),
                      child: const Icon(Icons.menu, size: 22, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ModelChip(
                    model: chat.currentModel,
                    onSwitch: () => _showModelPicker(context, ref),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            // 消息列表
            Expanded(
              child: chat.messages.isEmpty
                  ? const Center(
                      child: Text(
                        '内容由 AI 生成',
                        style: TextStyle(fontSize: AppFontSize.tiny, color: AppColors.text3),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: chat.messages.length,
                      itemBuilder: (context, i) {
                        final m = chat.messages[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MessageView(message: m),
                        );
                      },
                    ),
            ),
            // 输入栏
            Composer(
              onSend: (text) => notifier.send(text),
            ),
            const HomeBar(),
          ],
        ),
      ),
    );
  }

  /// 模型选择弹窗
  void _showModelPicker(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(chatProvider.notifier);
    final current = ref.read(chatProvider).currentModel;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E4E6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                '选择模型',
                style: TextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              ...kProviderBaseUrls.keys.map((provider) {
                final model = ModelConfig(
                  id: provider,
                  provider: provider,
                  apiKey: current.apiKey,
                  baseUrl: kProviderBaseUrls[provider]!,
                  modelName: provider == 'deepseek' ? 'deepseek-chat' : provider,
                );
                final selected = current.provider == provider;
                return ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 12,
                    color: selected ? AppColors.teal : AppColors.text3,
                  ),
                  title: Text(provider),
                  trailing: selected
                      ? const Icon(Icons.check, color: AppColors.teal)
                      : null,
                  onTap: () {
                    notifier.switchModel(model);
                    Navigator.of(context).pop();
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

/// 模型芯片
class _ModelChip extends StatelessWidget {
  const _ModelChip({required this.model, required this.onSwitch});

  final ModelConfig model;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSwitch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              model.provider == 'deepseek' ? 'Auto' : model.provider,
              style: const TextStyle(
                fontSize: AppFontSize.small,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.text2),
          ],
        ),
      ),
    );
  }
}

/// 消息视图（含中断标记）
class _MessageView extends StatelessWidget {
  const _MessageView({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatBubble(
          text: message.content.isEmpty ? '…' : message.content,
          isUser: message.role == ChatRole.user,
        ),
        if (message.isInterrupted)
          const Padding(
            padding: EdgeInsets.only(top: 4, left: 4),
            child: Text(
              '（已中断，正在用新模型重答）',
              style: TextStyle(fontSize: AppFontSize.tiny, color: AppColors.text3),
            ),
          ),
      ],
    );
  }
}
