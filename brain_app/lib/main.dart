/// EDITH Glasses OS — Brain App entry point.
/// Central orchestrator for HUD Egg, Hermes via Home Assistant, cross-platform.
/// EDITH is the assistant display name; Hermes on ZimaOS is the AI backend.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/foreground_service.dart';

void main() {
  HudForegroundService.init();
  runApp(const ProviderScope(child: EdithApp()));
}
