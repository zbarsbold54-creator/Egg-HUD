/// Wi-Fi provisioning guide for the HUD Egg.
///
/// The Egg opens AP HUD-Setup-XXXX, serves HTTP on 192.168.4.1:80.
/// GET / shows a form, POST /connect with ssid+password saves and reboots.
/// This helper provides the guide text and a direct POST helper.
/// Never ask the owner to paste passwords into chat. Never log passwords.
library;

import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

class HudProvisioning {
  static const String guideSteps = '''
1. Power the HUD Egg (USB or battery).
2. On your phone/computer, connect Wi-Fi to the AP named HUD-Setup-XXXX.
3. Open http://192.168.4.1 in your browser.
4. Enter your home 2.4 GHz Wi-Fi SSID and password in the form.
5. Tap Connect. The Egg saves credentials and reboots.
6. Reconnect your phone to your normal Wi-Fi network.
7. In this app, tap Discover HUD (or enter the Egg's IP manually).
''';

  /// POST credentials directly (alternative to browser form).
  /// Returns true on 200 OK.
  static Future<bool> provision(String ssid, String password) async {
    try {
      final res = await http.post(
        Uri.parse('http://${AppConfig.provisionIp}:${AppConfig.provisionPort}/connect'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'ssid': ssid, 'password': password},
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Check if the provisioning AP is reachable.
  static Future<bool> isProvisioningReachable() async {
    try {
      final res = await http.get(
        Uri.parse('http://${AppConfig.provisionIp}:${AppConfig.provisionPort}/'),
      ).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
