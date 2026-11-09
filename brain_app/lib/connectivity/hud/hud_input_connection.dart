/// Controller-input WebSocket client (port 82, separate from display WS port 81).
/// Receives JSON button events forwarded by the HUD Egg from the ESP-NOW controller.
/// Reconnects independently without affecting display frames.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/config/app_config.dart';
import 'hud_socket_factory.dart';

enum ControllerStatus { disconnected, searching, connecting, connected, reconnecting, error }

class HudInputEvent {
  final String type; // button_down | button_up | status
  final int seq;
  final int ts;
  final int durationMs;
  final ControllerStatus status;
  const HudInputEvent({required this.type, required this.seq, required this.ts, this.durationMs = 0, this.status = ControllerStatus.connected});
}

class HudInputConnection {
  static const Duration _timeout = Duration(seconds: 8);
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  ControllerStatus _status = ControllerStatus.disconnected;
  String? _url;
  int _attempts = 0;
  Timer? _timer;
  int _gen = 0;
  bool _want = false;
  bool _disposed = false;
  int _lastSeq = -1;
  final _events = StreamController<HudInputEvent>.broadcast();
  final _statusCtrl = StreamController<ControllerStatus>.broadcast();

  ControllerStatus get status => _status;
  Stream<ControllerStatus> get statusStream => _statusCtrl.stream;
  Stream<HudInputEvent> get events => _events.stream;
  bool get isConnected => _status == ControllerStatus.connected;

  static String? hostToUrl(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    s = s.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://'), '');
    s = s.split('/').first.trim();
    if (s.isEmpty) return null;
    if (!s.contains(':')) s = '$s:${AppConfig.hudInputPort}';
    return 'ws://$s';
  }

  void _set(ControllerStatus s) {
    if (_status == s) return;
    _status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  Future<bool> connect(String url) {
    _want = true;
    _attempts = 0;
    return _open(url);
  }

  void ensureConnected() {
    final url = _url;
    if (!_want || _disposed || url == null) return;
    if (_status == ControllerStatus.connected || _status == ControllerStatus.connecting) return;
    _attempts = 0;
    unawaited(_open(url));
  }

  Future<bool> _open(String url) async {
    if (_disposed) return false;
    final gen = ++_gen;
    _timer?.cancel();
    await _close();
    if (_disposed || gen != _gen) return false;
    _url = url;
    _set(ControllerStatus.connecting);
    debugPrint('[INPUT] connecting to $url');
    final WebSocketChannel ch;
    try {
      ch = connectHudSocket(Uri.parse(url));
    } catch (e) {
      return _fail(gen, e);
    }
    _channel = ch;
    _sub = ch.stream.listen((msg) {
      if (gen != _gen) return;
      _onMessage(msg);
    }, onError: (Object e) => _onEnded(gen), onDone: () => _onEnded(gen), cancelOnError: true);
    try {
      await ch.ready.timeout(_timeout);
    } catch (e) {
      return _fail(gen, e);
    }
    if (_disposed || gen != _gen) return false;
    _attempts = 0;
    _lastSeq = -1; // controller may have rebooted (seq reset)
    _set(ControllerStatus.connected);
    debugPrint('[INPUT] connected to $url');
    return true;
  }

  Future<bool> _fail(int gen, Object e) async {
    if (_disposed || gen != _gen) return false;
    debugPrint('[INPUT] connect failed: $e');
    await _close();
    if (_disposed || gen != _gen) return false;
    _set(ControllerStatus.error);
    _schedule();
    return false;
  }

  void _onEnded(int gen) {
    if (_disposed || gen != _gen) return;
    if (_status != ControllerStatus.connected) return;
    debugPrint('[INPUT] connection lost');
    unawaited(_close());
    if (!_want) { _set(ControllerStatus.disconnected); return; }
    _set(ControllerStatus.reconnecting);
    _schedule();
  }

  void _schedule() {
    final url = _url;
    if (!_want || _disposed || url == null) return;
    _timer?.cancel();
    final secs = math.min(30, 1 << math.min(_attempts, 5));
    _attempts++;
    _timer = Timer(Duration(seconds: secs), () {
      if (!_want || _disposed) return;
      unawaited(_open(url));
    });
  }

  void _onMessage(dynamic msg) {
    if (msg is! String) return;
    try {
      final j = jsonDecode(msg) as Map<String, dynamic>;
      final type = j['type'] as String? ?? '';
      final seq = (j['seq'] as num?)?.toInt() ?? 0;
      final ts = (j['ts'] as num?)?.toInt() ?? 0;
      if (type == 'status') {
        final code = (j['code'] as num?)?.toInt() ?? 0;
        if (code >= 0 && code < ControllerStatus.values.length) {
          final s = ControllerStatus.values[code];
          _set(s);
          // Controller CONNECTED means fresh session (possible reboot) — reset seq.
          if (s == ControllerStatus.connected) {
            _lastSeq = -1;
          }
        }
        return;
      }
      // Duplicate protection: ignore seq <= lastSeq, unless large backward jump (reboot/reset)
      if (type.startsWith('button')) {
        if (seq <= _lastSeq) {
          // Large backward jump (e.g. 1000 -> 0) means controller rebooted; accept as reset.
          if (_lastSeq - seq > 100) {
            _lastSeq = -1;
          } else {
            return;
          }
        }
      }
      _lastSeq = seq;
      final dur = (j['durationMs'] as num?)?.toInt() ?? 0;
      if (!_events.isClosed) {
        _events.add(HudInputEvent(type: type, seq: seq, ts: ts, durationMs: dur));
      }
    } catch (_) {}
  }

  Future<void> _close() async {
    final sub = _sub; final ch = _channel;
    _sub = null; _channel = null;
    try { await sub?.cancel(); } catch (_) {}
    try { await ch?.sink.close().timeout(const Duration(seconds: 2)); } catch (_) {}
  }

  Future<void> disconnect() async {
    _want = false; _timer?.cancel(); _gen++;
    await _close();
    _set(ControllerStatus.disconnected);
  }

  Future<void> dispose() async {
    _disposed = true; _want = false; _timer?.cancel(); _gen++;
    await _close();
    await _events.close();
    await _statusCtrl.close();
  }
}
