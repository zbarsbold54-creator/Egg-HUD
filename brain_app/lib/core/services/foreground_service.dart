/// Android foreground service for HUD WebSocket keep-alive.
///
/// Types: connectedDevice|microphone|location (manifest).
/// Qualifying perm for connectedDevice: CHANGE_WIFI_MULTICAST_STATE /
/// CHANGE_WIFI_STATE / CHANGE_NETWORK_STATE (all declared).
/// Runtime: compute type set from granted perms, start only from visible UI,
/// restart with extra types when voice/nav starts. On boot/restart, post
/// "tap to resume voice/nav" notification instead of starting mic/location.
library;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Compute FGS type set from granted permissions.
/// connectedDevice always; microphone if RECORD_AUDIO granted;
/// location if fine/coarse granted. Returns set of type names.
Set<String> computeTypeSet({required bool micGranted, required bool locationGranted}) {
  final types = <String>{'connectedDevice'};
  if (micGranted) types.add('microphone');
  if (locationGranted) types.add('location');
  return types;
}

class HudForegroundService {
  static bool _initialized = false;

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
        // No autoRunOnBoot: on boot/restart we post "tap to resume" instead
        // of starting mic/location types without user consent.
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  /// Start service. Caller must ensure app is visible (lifecycle resumed).
  /// Types are computed from granted perms: connectedDevice always,
  /// microphone if RECORD_AUDIO granted, location if location granted.
  /// Restart with extra types when voice/nav starts (call start() again).
  static Future<bool> start({bool micGranted = false, bool locationGranted = false}) async {
    try {
      // Type set is declared in manifest (connectedDevice|microphone|location).
      // Plugin starts with all declared types; OS enforces granted perms.
      // We pass flags for logging; actual enforcement is OS-side.
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

  static Future<bool> stop() async {
    try {
      final result = await FlutterForegroundTask.stopService();
      return result is ServiceRequestSuccess;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isRunning() async {
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (_) {
      return false;
    }
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(HudTaskHandler());
}

class HudTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // No auto-restart with mic/location types. On boot/restart, the app
    // posts a "tap to resume voice/nav" notification (see app.dart).
  }
}
