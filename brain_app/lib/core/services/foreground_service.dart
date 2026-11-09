/// Android foreground service for HUD WebSocket keep-alive.
///
/// Keeps the app running when the phone screen is off, so the HUD
/// WebSocket stays alive and the glasses remain available.
/// Uses flutter_foreground_task (Android only; no-op on desktop/web).
///
/// Permissions required (declared in AndroidManifest):
/// - FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC
/// - POST_NOTIFICATIONS (service notification, Android 13+)
/// - WAKE_LOCK (prevent CPU sleep while service runs)
///
/// The service runs a Dart isolate that keeps the app alive.
/// Keep-alive frames are sent by the main app's DisplayRenderer
/// when keepAwake is on. Do not promise uninterrupted background
/// when the OS prevents it (battery optimization, manufacturer killers).
library;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class HudForegroundService {
  static bool _initialized = false;

  /// Initialize foreground task options. Call once at app start.
  static void init() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'edith_hud_service',
        channelName: 'EDITH HUD Service',
        channelDescription: 'Keeps HUD WebSocket alive when screen is off',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  /// Start the foreground service (Android only).
  /// Returns true if started, false if not supported or failed.
  static Future<bool> start() async {
    try {
      final result = await FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: 'EDITH HUD Service',
        notificationText: 'Keeping HUD connection alive',
        callback: startCallback,
      );
      return result is ServiceRequestSuccess;
    } catch (_) {
      return false;
    }
  }

  /// Stop the foreground service.
  static Future<bool> stop() async {
    try {
      final result = await FlutterForegroundTask.stopService();
      return result is ServiceRequestSuccess;
    } catch (_) {
      return false;
    }
  }

  /// Check if service is running.
  static Future<bool> isRunning() async {
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (_) {
      return false;
    }
  }
}

/// Entry point for the foreground task isolate.
/// Must be a top-level function (not a method).
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(HudTaskHandler());
}

class HudTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Service started. The main isolate maintains the WebSocket;
    // this handler keeps the isolate alive. Keep-alive frames are
    // sent by the main app's DisplayRenderer when keepAwake is on.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Android 15 dataSync timeout: restart service or switch to specialUse.
    // flutter_foreground_task handles restart via autoRunOnBoot; log for diagnostics.
    if (isTimeout) {
      // ponytail: restart is handled by plugin; no custom logic needed.
    }
  }
}
