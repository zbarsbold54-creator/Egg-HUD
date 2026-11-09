/// Root app widget.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../connectivity/hud/hud_providers.dart';
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

  @override
  void initState() {
    super.initState();
    final hud = ref.read(hudConnectionProvider);
    final renderer = ref.read(displayRendererProvider);
    _lifecycle = AppLifecycle(hud: hud, renderer: renderer)..attach();
    // Connect to the glasses on launch (saved IP, else discovery).
    unawaited(autoConnectHud(hud));
  }

  @override
  void dispose() {
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
