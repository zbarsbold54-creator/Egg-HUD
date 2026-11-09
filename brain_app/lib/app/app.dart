/// Root app widget.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../connectivity/hud/hud_providers.dart';
import '../display/renderer/always_on_screen.dart';
import '../core/services/foreground_service.dart';
import '../core/theme/app_theme.dart';
import 'lifecycle.dart';
import 'router.dart';

class EdithApp extends ConsumerStatefulWidget {
  const EdithApp({super.key});

  @override
  ConsumerState<EdithApp> createState() => _EdithAppState();
}

class _EdithAppState extends ConsumerState<EdithApp> {
  AppLifecycle? _lifecycle;
  AlwaysOnScreen? _alwaysOn;

  @override
  void initState() {
    super.initState();
    final hud = ref.read(hudConnectionProvider);
    final renderer = ref.read(displayRendererProvider);
    final input = ref.read(hudInputConnectionProvider);
    final inputProvider = ref.read(hudInputProvider);
    _lifecycle = AppLifecycle(hud: hud, renderer: renderer)..attach();
    _alwaysOn = AlwaysOnScreen(renderer)..start();
    // Eager FGS start while visible (connectedDevice always; mic/location if granted).
    // Restart with larger set only when perm granted while visible (see Settings).
    unawaited(HudForegroundService.start());
    unawaited(inputProvider.start());
    // Connect to the glasses on launch (saved IP, else discovery).
    unawaited(
      autoConnectHud(hud).then((_) async {
        final url = hud.currentUrl;
        await autoConnectHudInput(input, url);
      }),
    );
  }

  @override
  void dispose() {
    _alwaysOn?.stop();
    _lifecycle?.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GLAS',
      theme: AppTheme.dark,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: '/',
      debugShowCheckedModeBanner: false,
    );
  }
}

// Backwards-compat alias
typedef JarvisApp = EdithApp;
