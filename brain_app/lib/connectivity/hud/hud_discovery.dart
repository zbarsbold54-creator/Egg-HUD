/// mDNS / DNS-SD discovery for the HUD Egg.
///
/// The Egg advertises hostname hud.local and service _ws._tcp on port 81.
/// Discovery order:
/// 1. DNS-SD: PTR (_ws._tcp.local) -> SRV (instance -> target host + port)
///    -> A record of the target host. The A record lives on the HOST
///    (hud.local), not on the service instance name, so the SRV hop matters.
/// 2. A record query for hud.local (hostname fallback)
/// 3. System resolver for hud.local (rarely works for .local on Android)
/// 4. The last saved IP, if it still answers on the HUD port
/// 5. Manual IP entry (always available in Settings)
///
/// Notes:
/// - Android filters multicast unless a multicast lock is held (and the app
///   declares CHANGE_WIFI_MULTICAST_STATE); we take the lock around discovery
///   through a small platform channel in MainActivity.kt.
/// - Browsers cannot do mDNS at all; on web discovery reports that and the
///   caller must use a manual IP.
/// - Never claim discovery succeeded without a reachable IP: every result is
///   checked with a TCP connect first.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:multicast_dns/multicast_dns.dart';
import '../../core/config/app_config.dart';

class HudDevice {
  final String hostname;
  final String ip;
  final int port;
  final String serviceType;

  const HudDevice({
    required this.hostname,
    required this.ip,
    required this.port,
    required this.serviceType,
  });

  String get wsUrl => 'ws://$ip:$port';
  String get displayName => '$hostname ($ip:$port)';

  @override
  String toString() => displayName;
}

/// Result of a discovery run: the devices found plus short human-readable
/// notes on what was tried, so the UI can say WHY nothing was found.
class HudDiscoveryReport {
  final List<HudDevice> devices;
  final List<String> notes;

  const HudDiscoveryReport({required this.devices, required this.notes});

  String get summary => notes.join(' ');
}

class HudDiscovery {
  static const MethodChannel _multicast =
      MethodChannel('com.jarvis.brain_app/multicast');

  /// "hud" from "hud.local".
  static String get _hostLabel => AppConfig.hudHostname.split('.').first.toLowerCase();

  /// Discover the HUD Egg. Returns an empty list if not found — the caller
  /// falls back to manual IP. Use [discoverWithReport] to also get the reasons.
  static Future<List<HudDevice>> discover({
    Duration timeout = const Duration(seconds: 3),
    String? lastKnownIp,
  }) async {
    final report = await discoverWithReport(timeout: timeout, lastKnownIp: lastKnownIp);
    return report.devices;
  }

  static Future<HudDiscoveryReport> discoverWithReport({
    Duration timeout = const Duration(seconds: 3),
    String? lastKnownIp,
  }) async {
    final devices = <HudDevice>[];
    final notes = <String>[];

    if (kIsWeb) {
      notes.add('Browsers cannot discover devices (no mDNS). '
          'Enter the HUD IP shown on the glasses or in the serial log.');
      return HudDiscoveryReport(devices: devices, notes: notes);
    }

    final lockHeld = await _setMulticastLock(true);
    try {
      await _discoverDnsSd(devices, notes, timeout);
      if (devices.isEmpty) await _discoverHostname(devices, notes, timeout);
      if (devices.isEmpty) await _discoverSystemResolver(devices, notes, timeout);
    } finally {
      if (lockHeld) await _setMulticastLock(false);
    }

    final saved = lastKnownIp?.trim() ?? '';
    if (devices.isEmpty && saved.isNotEmpty) {
      if (await isReachable(saved)) {
        devices.add(_device(saved, AppConfig.hudPort));
        notes.add('mDNS found nothing, but the saved IP $saved answers on port ${AppConfig.hudPort}.');
      } else {
        notes.add('The saved IP $saved does not answer on port ${AppConfig.hudPort}.');
      }
    }

    if (devices.isEmpty) {
      notes.add('Check that the Egg is powered, shows an IP on its screen (state RUNNING), '
          'and is on the same 2.4 GHz WiFi as this device (no guest/isolated network).');
    }
    return HudDiscoveryReport(devices: devices, notes: notes);
  }

  static HudDevice _device(String ip, int port) => HudDevice(
        hostname: AppConfig.hudHostname,
        ip: ip,
        port: port,
        serviceType: AppConfig.hudServiceType,
      );

  static Future<void> _addIfReachable(List<HudDevice> out, String ip, int port) async {
    if (out.any((d) => d.ip == ip)) return;
    if (await isReachable(ip, port: port)) out.add(_device(ip, port));
  }

  /// 1. PTR -> SRV -> A. Stops at the first reachable HUD.
  static Future<void> _discoverDnsSd(
      List<HudDevice> out, List<String> notes, Duration timeout) async {
    final client = MDnsClient();
    try {
      await client.start();
      await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('${AppConfig.hudServiceType}.local'),
        timeout: timeout,
      )) {
        await for (final SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
          timeout: timeout,
        )) {
          // Other devices on the LAN may advertise _ws._tcp too; only accept the HUD.
          final isHud = ptr.domainName.toLowerCase().startsWith('$_hostLabel.') ||
              srv.target.toLowerCase().startsWith('$_hostLabel.');
          if (!isHud) continue;

          await for (final IPAddressResourceRecord a in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
            timeout: timeout,
          )) {
            await _addIfReachable(out, a.address.address, srv.port);
            if (out.isNotEmpty) return;
          }
        }
      }
      notes.add('DNS-SD: no HUD answered.');
    } catch (e) {
      debugPrint('[HUD] DNS-SD discovery error: $e');
      notes.add('DNS-SD unavailable (${e.runtimeType}); multicast may be blocked on this network/device.');
    } finally {
      client.stop();
    }
  }

  /// 2. A record for hud.local over mDNS.
  static Future<void> _discoverHostname(
      List<HudDevice> out, List<String> notes, Duration timeout) async {
    final client = MDnsClient();
    try {
      await client.start();
      await for (final IPAddressResourceRecord a in client.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv4(AppConfig.hudHostname),
        timeout: timeout,
      )) {
        await _addIfReachable(out, a.address.address, AppConfig.hudPort);
        if (out.isNotEmpty) return;
      }
      notes.add('${AppConfig.hudHostname}: no mDNS answer.');
    } catch (e) {
      debugPrint('[HUD] hostname discovery error: $e');
      notes.add('${AppConfig.hudHostname} lookup failed (${e.runtimeType}).');
    } finally {
      client.stop();
    }
  }

  /// 3. System resolver (works on some desktops, usually not on Android).
  static Future<void> _discoverSystemResolver(
      List<HudDevice> out, List<String> notes, Duration timeout) async {
    final ip = await resolveHudLocal().timeout(timeout, onTimeout: () => null);
    if (ip != null) {
      await _addIfReachable(out, ip, AppConfig.hudPort);
    }
  }

  /// Resolve hud.local to an IPv4 address via system DNS.
  static Future<String?> resolveHudLocal() async {
    try {
      final result = await InternetAddress.lookup(
        AppConfig.hudHostname,
        type: InternetAddressType.IPv4,
      );
      if (result.isNotEmpty) return result.first.address;
    } catch (_) {}
    return null;
  }

  /// Test if an IP is reachable (TCP connect with short timeout).
  static Future<bool> isReachable(String ip, {int port = AppConfig.hudPort}) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Android only: hold/release a WifiManager.MulticastLock (see MainActivity.kt).
  /// Returns true if the lock was acquired (or released).
  static Future<bool> _setMulticastLock(bool acquire) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      await _multicast.invokeMethod<bool>(acquire ? 'acquire' : 'release');
      return true;
    } catch (e) {
      debugPrint('[HUD] multicast lock ${acquire ? 'acquire' : 'release'} failed: $e');
      return false;
    }
  }
}
