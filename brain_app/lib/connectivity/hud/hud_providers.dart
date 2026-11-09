/// App-wide HUD providers. ONE shared connection and renderer for the whole
/// app: screens read these instead of creating their own HudConnection.
library;

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/settings_store.dart';
import '../../display/renderer/display_renderer.dart';
import '../../display/transformations/display_transform.dart';
import '../../core/config/app_config.dart';
import '../../input/hud_input_provider.dart';
import '../../input/input_state_machine.dart';
import 'hud_connection.dart';
import 'hud_discovery.dart';
import 'hud_input_connection.dart';

/// The single shared connection to the glasses.
final hudConnectionProvider = Provider<HudConnection>((ref) {
  final connection = HudConnection();
  ref.onDispose(() => unawaited(connection.dispose()));
  return connection;
});

/// Live connection state (emits the current state first).
final hudStateProvider = StreamProvider<HudConnectionState>((ref) async* {
  final connection = ref.watch(hudConnectionProvider);
  yield connection.state;
  yield* connection.stateStream;
});

/// Shared render engine; its frames go to the shared connection.
final displayRendererProvider = Provider<DisplayRenderer>((ref) {
  final connection = ref.watch(hudConnectionProvider);
  final renderer = DisplayRenderer();
  renderer.setSink((bytes) => connection.sendFrame(bytes));
  // Apply saved orientation (flip/rotation) on launch.
  unawaited((() async {
    try {
      renderer.setTransform(DisplayTransform(
        flipHorizontal: await SettingsStore.getFlipHorizontal(),
        flipVertical: await SettingsStore.getFlipVertical(),
        rotation: await SettingsStore.getRotation(),
        invert: await SettingsStore.getInvert(),
      ));
    } catch (_) {}
  })());
  ref.onDispose(renderer.dispose);
  return renderer;
});

/// The URL to (re)connect to from saved settings, or null if none is set.
Future<String?> savedHudUrl() async {
  if (await SettingsStore.getUseCorsProxy()) {
    final proxy = (await SettingsStore.getProxyUrl()).trim();
    return proxy.isEmpty ? null : proxy;
  }
  return HudConnection.hostToUrl(await SettingsStore.getHudIp());
}

/// Connect on app launch: saved target first; with nothing saved, try
/// discovery once and remember the result. If the saved IP no longer works
/// (DHCP handed the Egg a new address) discovery runs once to find it.
/// Never throws.
Future<void> autoConnectHud(HudConnection hud) async {
  try {
    final useProxy = await SettingsStore.getUseCorsProxy();
    final savedIp = await SettingsStore.getHudIp();
    var url = await savedHudUrl();

    if (url != null) {
      final ok = await hud.connect(url);
      if (ok || useProxy) return;
    }

    final report = await HudDiscovery.discoverWithReport(lastKnownIp: null);
    if (report.devices.isEmpty) {
      debugPrint('[HUD] auto-connect: ${report.summary}');
      return;
    }
    final found = report.devices.first;
    if (found.wsUrl == url) return; // same target, already retrying
    if (found.ip != savedIp.trim()) await SettingsStore.setHudIp(found.ip);
    await hud.connect(found.wsUrl);
  } catch (e) {
    debugPrint('[HUD] auto-connect skipped: $e');
  }
}

/// Shared controller-input connection (port 82, independent of display WS).
final hudInputConnectionProvider = Provider<HudInputConnection>((ref) {
  final c = HudInputConnection();
  ref.onDispose(() => unawaited(c.dispose()));
  return c;
});

final controllerStatusProvider = StreamProvider<ControllerStatus>((ref) async* {
  final c = ref.watch(hudInputConnectionProvider);
  yield c.status;
  yield* c.statusStream;
});

final inputStateMachineProvider = Provider<InputStateMachine>((ref) {
  final sm = InputStateMachine();
  unawaited((() async {
    try {
      sm.setTiming(InputTimingConfig(
        shortPressMax: Duration(milliseconds: await SettingsStore.getShortMax()),
        doublePressWindow: Duration(milliseconds: await SettingsStore.getDoubleWindow()),
        veryLongPress: Duration(milliseconds: await SettingsStore.getVeryLong()),
        debounce: Duration(milliseconds: await SettingsStore.getDebounce()),
      ));
    } catch (_) {}
  })());
  ref.onDispose(sm.dispose);
  return sm;
});

final hudInputProvider = Provider<HudInputProvider>((ref) {
  final p = HudInputProvider(
    connection: ref.watch(hudInputConnectionProvider),
    stateMachine: ref.watch(inputStateMachineProvider),
  );
  ref.onDispose(() => unawaited(p.stop()));
  return p;
});

Future<void> autoConnectHudInput(
  HudInputConnection input,
  String? displayUrl,
) async {
  try {
    if (displayUrl == null) return;
    final uri = Uri.parse(displayUrl);
    await input.connect('ws://${uri.host}:${AppConfig.hudInputPort}');
  } catch (e) {
    debugPrint('[INPUT] auto-connect skipped: $e');
  }
}
