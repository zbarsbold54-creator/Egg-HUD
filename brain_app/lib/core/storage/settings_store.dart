/// Persistent settings store. All settings survive restarts.
/// Uses SharedPreferences for non-sensitive data, SecureStorage for tokens.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsStore {
  static final _prefs = SharedPreferencesAsync();
  static const _secure = FlutterSecureStorage();

  // Display
  static Future<void> setFlipHorizontal(bool v) => _prefs.setBool('flipH', v);
  static Future<bool> getFlipHorizontal() async => (await _prefs.getBool('flipH')) ?? false;
  static Future<void> setFlipVertical(bool v) => _prefs.setBool('flipV', v);
  static Future<bool> getFlipVertical() async => (await _prefs.getBool('flipV')) ?? false;
  static Future<void> setRotation(int v) => _prefs.setInt('rotation', v);
  static Future<int> getRotation() async => (await _prefs.getInt('rotation')) ?? 90;
  static Future<void> setInvert(bool v) => _prefs.setBool('invert', v);
  static Future<bool> getInvert() async => (await _prefs.getBool('invert')) ?? false;
  static Future<void> setThreshold(double v) => _prefs.setDouble('threshold', v);
  static Future<double> getThreshold() async => (await _prefs.getDouble('threshold')) ?? 1.0;
  static Future<void> setAnimationSpeed(double v) => _prefs.setDouble('animSpeed', v);
  static Future<double> getAnimationSpeed() async => (await _prefs.getDouble('animSpeed')) ?? 1.0;
  static Future<void> setScreenTimeout(int v) => _prefs.setInt('screenTimeout', v);
  static Future<int> getScreenTimeout() async => (await _prefs.getInt('screenTimeout')) ?? 30;

  // Connection
  static Future<void> setHudIp(String v) => _prefs.setString('hudIp', v);
  static Future<String> getHudIp() async => (await _prefs.getString('hudIp')) ?? '';
  static Future<void> setUseCorsProxy(bool v) => _prefs.setBool('useCorsProxy', v);
  static Future<bool> getUseCorsProxy() async => (await _prefs.getBool('useCorsProxy')) ?? false;
  static Future<void> setProxyUrl(String v) => _prefs.setString('proxyUrl', v);
  static Future<String> getProxyUrl() async => (await _prefs.getString('proxyUrl')) ?? 'ws://localhost:8081/ws';
  static Future<void> setKeepAwake(bool v) => _prefs.setBool('keepAwake', v);
  static Future<bool> getKeepAwake() async => (await _prefs.getBool('keepAwake')) ?? false;
  static Future<void> setKeepAliveInterval(int v) => _prefs.setInt('keepAliveInterval', v);
  static Future<int> getKeepAliveInterval() async => (await _prefs.getInt('keepAliveInterval')) ?? 10;

  // EDITH
  static Future<void> setHaUrl(String v) => _prefs.setString('haUrl', v);
  static Future<String> getHaUrl() async => (await _prefs.getString('haUrl')) ?? '';
  static Future<void> setHaAgentId(String v) => _prefs.setString('haAgentId', v);
  static Future<String> getHaAgentId() async => (await _prefs.getString('haAgentId')) ?? '';
  static Future<void> setSpeechRate(double v) => _prefs.setDouble('speechRate', v);
  static Future<double> getSpeechRate() async => (await _prefs.getDouble('speechRate')) ?? 0.5;
  static Future<void> setSpeechVolume(double v) => _prefs.setDouble('speechVolume', v);
  static Future<double> getSpeechVolume() async => (await _prefs.getDouble('speechVolume')) ?? 1.0;
  static Future<void> setRecognitionLanguage(String v) => _prefs.setString('recLang', v);
  static Future<String> getRecognitionLanguage() async => (await _prefs.getString('recLang')) ?? 'en-US';
  static Future<void> setVerbosity(String v) => _prefs.setString('verbosity', v);
  static Future<String> getVerbosity() async => (await _prefs.getString('verbosity')) ?? 'normal';
  static Future<void> setPushToTalk(bool v) => _prefs.setBool('pushToTalk', v);
  static Future<bool> getPushToTalk() async => (await _prefs.getBool('pushToTalk')) ?? true;

  // Secure tokens (never in SharedPreferences, never in logs)
  static Future<void> setHaToken(String v) => _secure.write(key: 'ha_token', value: v);
  static Future<String?> getHaToken() => _secure.read(key: 'ha_token');
  static Future<void> deleteHaToken() => _secure.delete(key: 'ha_token');

  // Idle (minutes before blank + sleep)
  static Future<void> setIdleTimeoutMin(int v) => _prefs.setInt('idleTimeoutMin', v);
  static Future<int> getIdleTimeoutMin() async => (await _prefs.getInt('idleTimeoutMin')) ?? 5;

  // Navigation (OSRM)
  static Future<void> setOsrmEndpoint(String v) => _prefs.setString('osrmEndpoint', v);
  static Future<String> getOsrmEndpoint() async => (await _prefs.getString('osrmEndpoint')) ?? 'https://router.project-osrm.org';
  static Future<void> setOsrmProfile(String v) => _prefs.setString('osrmProfile', v);
  static Future<String> getOsrmProfile() async => (await _prefs.getString('osrmProfile')) ?? 'foot';

  // Input timing (ms)
  static Future<void> setShortMax(int v) => _prefs.setInt('shortMax', v);
  static Future<int> getShortMax() async => (await _prefs.getInt('shortMax')) ?? 400;
  static Future<void> setDoubleWindow(int v) => _prefs.setInt('doubleWindow', v);
  static Future<int> getDoubleWindow() async => (await _prefs.getInt('doubleWindow')) ?? 350;
  static Future<void> setVeryLong(int v) => _prefs.setInt('veryLong', v);
  static Future<int> getVeryLong() async => (await _prefs.getInt('veryLong')) ?? 2000;
  static Future<void> setDebounce(int v) => _prefs.setInt('debounce', v);
  static Future<int> getDebounce() async => (await _prefs.getInt('debounce')) ?? 50;

  // Personalization
  static Future<void> setCharacterStyle(String v) => _prefs.setString('charStyle', v);
  static Future<String> getCharacterStyle() async => (await _prefs.getString('charStyle')) ?? 'default';
  static Future<void> setClockStyle(String v) => _prefs.setString('clockStyle', v);
  static Future<String> getClockStyle() async => (await _prefs.getString('clockStyle')) ?? 'digital';
  static Future<void> setScrollSpeed(double v) => _prefs.setDouble('scrollSpeed', v);
  static Future<double> getScrollSpeed() async => (await _prefs.getDouble('scrollSpeed')) ?? 20.0;
}
