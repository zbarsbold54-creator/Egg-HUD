/// Application configuration and constants.
/// Frozen protocol constants live here — do not change without firmware change.
library;

class AppConfig {
  // HUD Egg protocol (frozen)
  static const String hudHostname = 'hud.local';
  static const String hudServiceType = '_ws._tcp';
  static const int hudPort = 81;
  static const int hudInputPort = 82;
  static const int frameWidth = 128;
  static const int frameHeight = 64;
  static const int frameBytes = 1024;
  static const int hudIdleTimeoutSeconds = 30;

  // Provisioning
  static const String provisionApPrefix = 'HUD-Setup-';
  static const String provisionIp = '192.168.4.1';
  static const int provisionPort = 80;

  // Keep-alive (safely below 30s firmware timeout)
  static const Duration defaultKeepAliveInterval = Duration(seconds: 10);

  // App identity — EDITH is the assistant display name.
  // Hermes on ZimaOS remains the underlying AI intelligence.
  static const String appName = 'GLAS';
  static const String assistantName = 'EDITH';
  static const String appVersion = '1.0.0';
}
