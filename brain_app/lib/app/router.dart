/// App router and global providers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../display/renderer/display_animation.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/assistant/assistant_screen.dart';
import '../features/navigation/navigation_screen.dart';
import '../features/music/music_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/translator/translator_screen.dart';
import '../features/teleprompter/teleprompter_screen.dart';
import '../features/chess/chess_screen.dart';
import '../features/sound/sound_screen.dart';
import '../features/tools/tools_screen.dart';
import '../features/settings/settings_screen.dart';
import '../display/simulator/display_preview.dart';

final edithStateProvider = StateProvider<EdithState>((ref) => EdithState.idle);
// Backwards-compat alias
final jarvisStateProvider = edithStateProvider;
final hudFrameProvider = StateProvider<List<int>>((ref) => List<int>.filled(1024, 0));

extension RouterX on BuildContext {
  void go(String path) {
    Navigator.of(this).pushNamed(path);
  }
}

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '/';
    Widget page;
    switch (name) {
      case '/':
        page = const DashboardScreen();
        break;
      case '/assistant':
        page = const AssistantScreen();
        break;
      case '/navigation':
        page = const NavigationScreen();
        break;
      case '/music':
        page = const MusicScreen();
        break;
      case '/notifications':
        page = const NotificationsScreen();
        break;
      case '/translator':
        page = const TranslatorScreen();
        break;
      case '/teleprompter':
        page = const TeleprompterScreen();
        break;
      case '/chess':
        page = const ChessScreen();
        break;
      case '/sound':
        page = const SoundScreen();
        break;
      case '/tools':
        page = const ToolsScreen();
        break;
      case '/settings':
        page = const SettingsScreen();
        break;
      case '/simulator':
        page = const SimulatorScreen();
        break;
      default:
        page = const DashboardScreen();
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}

class SimulatorScreen extends ConsumerWidget {
  const SimulatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frame = ref.watch(hudFrameProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('HUD Simulator')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DisplayPreview(frameBytes: frame, scale: 4.0, showGrid: true, showFrameInfo: true),
            const SizedBox(height: 16),
            const Text('128x64 • 1-bit • 1024 bytes • SSD130x page layout'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                ref.read(hudFrameProvider.notifier).state = List<int>.filled(1024, 0xAA);
              },
              child: const Text('Send Checkerboard (demo)'),
            ),
          ],
        ),
      ),
    );
  }
}
