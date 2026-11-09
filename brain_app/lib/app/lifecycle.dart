/// App lifecycle handling: network recovery, WebSocket reconnect, screen
/// restoration. Call [attach] once at startup and [detach] on shutdown.
library;

import 'dart:async';
import 'package:flutter/widgets.dart';
import '../connectivity/hud/hud_connection.dart';
import '../display/renderer/display_renderer.dart';

class AppLifecycle extends WidgetsBindingObserver {
  final HudConnection hud;
  final DisplayRenderer renderer;
  final bool keepAwake;
  StreamSubscription<HudConnectionState>? _sub;

  AppLifecycle({required this.hud, required this.renderer, this.keepAwake = false});

  void attach() {
    WidgetsBinding.instance.addObserver(this);
    // Whenever the socket (re)connects, restore the current screen on the glasses.
    _sub = hud.stateStream.listen((s) {
      if (s == HudConnectionState.connected) renderer.forceFrame();
    });
  }

  void detach() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _sub = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The OS may have killed the socket while we were in the background.
      hud.ensureConnected();
      // Restore previous screen after reconnect.
      renderer.forceFrame();
    }
    // On pause: Android's foreground service keeps the WS alive when keepAwake
    // is on. Do not promise uninterrupted background when the OS prevents it.
  }
}
