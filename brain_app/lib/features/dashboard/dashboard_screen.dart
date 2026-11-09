/// Main dashboard screen. Context-aware, with EDITH orb center,
/// status top, media/contextual bottom. Restores screen context.
/// EDITH is the assistant display name; Hermes on ZimaOS is the AI backend.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../display/renderer/display_animation.dart';
import '../../widgets/character/edith_character.dart';
import '../../widgets/status_indicators/status_indicators.dart';
import '../../widgets/navigation_components/navigation_components.dart';
import '../../app/router.dart';
import '../../connectivity/hud/hud_input_connection.dart';
import '../../connectivity/hud/hud_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edithState = ref.watch(edithStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('EDITH')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StatusBar(
            clock: TimeOfDay.now().format(context),
            phoneBattery: 0.85,
            hudConnected: true,
            wifiConnected: true,
            bluetoothConnected: true,
            assistantConnected: true,
          ),
          const SizedBox(height: 24),
          Center(child: EdithCharacter(state: edithState, size: 140)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _stateLabel(edithState),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          ref
              .watch(controllerStatusProvider)
              .when(
                data: (s) => Text(
                  'Controller: ${s.name.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: s == ControllerStatus.connected
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                loading: () => const Text(
                  'Controller: ...',
                  style: TextStyle(fontSize: 12),
                ),
                error: (_, _) => const Text(
                  'Controller: ERROR',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
          const SizedBox(height: 24),
          ModuleGrid(
            items: [
              ModuleItem(
                icon: Icons.smart_toy,
                label: 'EDITH',
                onTap: () => context.go('/assistant'),
              ),
              ModuleItem(
                icon: Icons.navigation,
                label: 'Navigate',
                onTap: () => context.go('/navigation'),
              ),
              ModuleItem(
                icon: Icons.music_note,
                label: 'Music',
                onTap: () => context.go('/music'),
              ),
              ModuleItem(
                icon: Icons.notifications,
                label: 'Alerts',
                onTap: () => context.go('/notifications'),
              ),
              ModuleItem(
                icon: Icons.translate,
                label: 'Translate',
                onTap: () => context.go('/translator'),
              ),
              ModuleItem(
                icon: Icons.text_fields,
                label: 'Teleprompter',
                onTap: () => context.go('/teleprompter'),
              ),
              ModuleItem(
                icon: Icons.sports_esports,
                label: 'Chess',
                onTap: () => context.go('/chess'),
              ),
              ModuleItem(
                icon: Icons.volume_up,
                label: 'Sound',
                onTap: () => context.go('/sound'),
              ),
              ModuleItem(
                icon: Icons.build,
                label: 'Tools',
                onTap: () => context.go('/tools'),
              ),
              ModuleItem(
                icon: Icons.settings,
                label: 'Settings',
                onTap: () => context.go('/settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _stateLabel(EdithState s) {
    switch (s) {
      case EdithState.idle:
        return 'Idle';
      case EdithState.listening:
        return 'Listening...';
      case EdithState.thinking:
        return 'Thinking...';
      case EdithState.processing:
        return 'Processing...';
      case EdithState.speaking:
        return 'Speaking...';
      case EdithState.executing:
        return 'Executing...';
      case EdithState.waiting:
        return 'Waiting...';
      case EdithState.success:
        return 'Done';
      case EdithState.error:
        return 'Error';
      case EdithState.offline:
        return 'Offline';
    }
  }
}
