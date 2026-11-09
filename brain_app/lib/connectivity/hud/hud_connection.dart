/// WebSocket connection to the HUD Egg.
///
/// Distinguishes:
/// - Device discovered
/// - WebSocket connected
/// - Frame submitted to local socket
/// - Physical screen confirmed (external test only — never claimed from send)
///
/// The Egg never sends anything back. No handshake, no ack.
///
/// There is ONE shared instance for the whole app (see hud_providers.dart).
/// Reconnect rules:
/// - [connect] records the user's intent to be connected. From then on a lost
///   or failed connection is retried with exponential backoff (1 s ... 30 s)
///   until [disconnect] is called.
/// - Only one place schedules retries ([_scheduleReconnect]); every attempt
///   carries a generation number so callbacks from an old socket are ignored.
/// - [ensureConnected] retries immediately (app resume, network change).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/config/app_config.dart';
import 'hud_socket_factory.dart';

enum HudConnectionState {
  disconnected,
  discovering,
  connecting,
  connected,
  reconnecting,
  error,
}

class HudConnection {
  static const Duration _connectTimeout = Duration(seconds: 8);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _streamSub;
  HudConnectionState _state = HudConnectionState.disconnected;
  String? _currentUrl;
  String? _lastError;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  int _generation = 0;
  bool _wantConnected = false;
  bool _disposed = false;
  final StreamController<HudConnectionState> _stateController =
      StreamController<HudConnectionState>.broadcast();

  HudConnectionState get state => _state;
  Stream<HudConnectionState> get stateStream => _stateController.stream;
  String? get currentUrl => _currentUrl;
  String? get lastError => _lastError;
  bool get isConnected => _state == HudConnectionState.connected;

  /// Turns what a person types into a HUD URL: "192.168.1.27",
  /// "192.168.1.27:81" or "ws://192.168.1.27:81/" all become
  /// "ws://192.168.1.27:81". Returns null for empty input.
  static String? hostToUrl(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    s = s.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://'), '');
    s = s.split('/').first.trim();
    if (s.isEmpty) return null;
    if (!s.contains(':')) s = '$s:${AppConfig.hudPort}';
    return 'ws://$s';
  }

  void _setState(HudConnectionState s) {
    if (_state == s) return;
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  /// Connect to [url] (e.g. ws://192.168.1.50:81 or ws://hud.local:81) and
  /// keep reconnecting until [disconnect]. Returns true if this attempt
  /// connected; on false, [lastError] says why and retries continue in the
  /// background.
  Future<bool> connect(String url) {
    _wantConnected = true;
    _reconnectAttempts = 0;
    return _open(url);
  }

  /// Retry right now if we are supposed to be connected but are not
  /// (app resumed, network came back). No-op otherwise.
  void ensureConnected() {
    final url = _currentUrl;
    if (!_wantConnected || _disposed || url == null) return;
    if (_state == HudConnectionState.connected ||
        _state == HudConnectionState.connecting) {
      return;
    }
    _reconnectAttempts = 0;
    unawaited(_open(url));
  }

  Future<bool> _open(String url) async {
    if (_disposed) return false;
    final gen = ++_generation;
    _reconnectTimer?.cancel();
    await _closeChannel();
    if (_disposed || gen != _generation) return false;

    _currentUrl = url;
    _lastError = null;
    _setState(HudConnectionState.connecting);
    debugPrint('[HUD] connecting to $url');

    final WebSocketChannel channel;
    try {
      channel = connectHudSocket(Uri.parse(url));
    } catch (e) {
      return _failOpen(gen, e);
    }
    _channel = channel;

    // Listen from the start: on some platforms a refused connection shows up
    // as a stream error as well as a failed `ready`. Failures during
    // connecting are reported by _failOpen, not here.
    _streamSub = channel.stream.listen(
      (_) {
        // Egg never sends anything back. Ignore.
      },
      onError: (Object e) => _onStreamEnded(gen, e),
      onDone: () => _onStreamEnded(gen, null),
      cancelOnError: true,
    );

    try {
      await channel.ready.timeout(_connectTimeout);
    } catch (e) {
      return _failOpen(gen, e);
    }
    if (_disposed || gen != _generation) return false; // superseded

    _reconnectAttempts = 0;
    _setState(HudConnectionState.connected);
    debugPrint('[HUD] connected to $url');
    return true;
  }

  Future<bool> _failOpen(int gen, Object error) async {
    if (_disposed || gen != _generation) return false; // superseded
    _lastError = _describe(error);
    debugPrint('[HUD] connect failed: $_lastError');
    await _closeChannel();
    if (_disposed || gen != _generation) return false;
    _setState(HudConnectionState.error);
    _scheduleReconnect();
    return false;
  }

  void _onStreamEnded(int gen, Object? error) {
    if (_disposed || gen != _generation) return;
    if (error != null) _lastError = _describe(error);
    // While connecting, _open()/_failOpen() report the outcome.
    if (_state != HudConnectionState.connected) return;

    _lastError ??= 'Connection closed by the HUD';
    debugPrint('[HUD] connection lost: $_lastError');
    unawaited(_closeChannel());
    if (!_wantConnected) {
      _setState(HudConnectionState.disconnected);
      return;
    }
    _setState(HudConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final url = _currentUrl;
    if (!_wantConnected || _disposed || url == null) return;
    _reconnectTimer?.cancel();
    final secs = math.min(30, 1 << math.min(_reconnectAttempts, 5));
    _reconnectAttempts++;
    debugPrint('[HUD] retry in ${secs}s (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(Duration(seconds: secs), () {
      if (!_wantConnected || _disposed) return;
      unawaited(_open(url));
    });
  }

  /// Send a 1024-byte binary frame. Returns true if submitted to socket.
  /// Does NOT prove physical display — only local socket write.
  bool sendFrame(List<int> bytes) {
    if (bytes.length != AppConfig.frameBytes) return false;
    final channel = _channel;
    if (channel == null || !isConnected) return false;
    try {
      channel.sink.add(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _closeChannel() async {
    final sub = _streamSub;
    final channel = _channel;
    _streamSub = null;
    _channel = null;
    try {
      await sub?.cancel();
    } catch (_) {}
    try {
      await channel?.sink.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  String _describe(Object e) {
    if (e is TimeoutException) {
      return 'timed out after ${_connectTimeout.inSeconds} s (no answer from the Egg)';
    }
    final s = e.toString();
    return s.length > 200 ? '${s.substring(0, 200)}...' : s;
  }

  /// Stop, and stop retrying.
  Future<void> disconnect() async {
    _wantConnected = false;
    _reconnectTimer?.cancel();
    _generation++;
    await _closeChannel();
    _setState(HudConnectionState.disconnected);
  }

  Future<void> dispose() async {
    _disposed = true;
    _wantConnected = false;
    _reconnectTimer?.cancel();
    _generation++;
    await _closeChannel();
    await _stateController.close();
  }
}
