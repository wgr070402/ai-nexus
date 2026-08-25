import 'package:go_router/go_router.dart';
import '../features/engine/codex_page.dart';
import '../features/engine/env_status_page.dart';
import '../features/engine/harness_chat_page.dart';
import '../features/engine/harness_setup_page.dart';
import '../features/home/home_shell.dart';
import '../features/settings/agents_page.dart';
import '../features/settings/group_chat_settings_page.dart';
import '../features/settings/knowledge_page.dart';
import '../features/settings/models_engines_page.dart';
import '../features/settings/search_multimodal_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/terminal_env_page.dart';

/// 全局路由表
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeShell()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
    GoRoute(path: '/settings/models-engines', builder: (context, state) => const ModelsEnginesPage()),
    GoRoute(path: '/settings/terminal-env', builder: (context, state) => const TerminalEnvPage()),
    GoRoute(path: '/settings/group-chat', builder: (context, state) => const GroupChatSettingsPage()),
    GoRoute(path: '/settings/agents', builder: (context, state) => const AgentsPage()),
    GoRoute(path: '/settings/knowledge', builder: (context, state) => const KnowledgePage()),
    GoRoute(path: '/settings/search-multimodal', builder: (context, state) => const SearchMultimodalPage()),
    GoRoute(path: '/engine/harness-setup', builder: (context, state) => const HarnessSetupPage()),
    GoRoute(path: '/engine/harness-chat', builder: (context, state) => const HarnessChatPage()),
    GoRoute(path: '/engine/codex', builder: (context, state) => const CodexPage()),
    GoRoute(path: '/engine/env-status', builder: (context, state) => const EnvStatusPage()),
  ],
);
