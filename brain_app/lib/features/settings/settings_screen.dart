/// Settings application. All settings persist after restarts.
/// Display, Calibration, Connection, EDITH, Interaction, Personalization, Power.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/settings_store.dart';
import '../../core/services/foreground_service.dart';
import '../../connectivity/hud/hud_discovery.dart';
import '../../connectivity/hud/hud_connection.dart';
import '../../connectivity/hud/hud_providers.dart';
import '../../display/transformations/display_transform.dart';
import '../../connectivity/hud/hud_provisioning.dart';
import '../../connectivity/home_assistant/home_assistant_client.dart';
import '../../display/encoders/display_frame_encoder.dart';
import 'audio_device_status.dart';
import 'input_timing_settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _flipH = false;
  bool _flipV = false;
  int _rotation = 0;
  bool _invert = false;
  double _threshold = 1.0;
  double _animSpeed = 1.0;
  int _screenTimeout = 30;
  String _hudIp = '';
  bool _useCorsProxy = false;
  String _proxyUrl = 'ws://localhost:8081/ws';
  bool _keepAwake = false;
  int _keepAliveInterval = 10;
  String _haUrl = '';
  String _haAgentId = '';
  String _haToken = '';
  double _speechRate = 0.5;
  double _speechVolume = 1.0;
  String _recLang = 'en-US';
  String _verbosity = 'normal';
  bool _pushToTalk = true;
  String _hudStatus = 'Not connected';
  String _haStatus = 'Not tested';
  List<HudDevice> _discovered = [];
  // The ONE shared connection (see hud_providers.dart). Never create a
  // HudConnection here: it would die with this screen and nothing else
  // in the app could use it.
  HudConnection get _hud => ref.read(hudConnectionProvider);
  bool _hudConnected = false;
  bool _hudActive = false; // connecting, connected, or retrying in the background
  StreamSubscription<HudConnectionState>? _hudSub;
  final TextEditingController _ipCtl = TextEditingController();
  final TextEditingController _proxyCtl = TextEditingController();
  final TextEditingController _haUrlCtl = TextEditingController();
  final TextEditingController _haAgentCtl = TextEditingController();
  final TextEditingController _haTokenCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _hudConnected = _hud.isConnected;
    _hudActive = _hud.state != HudConnectionState.disconnected;
    _hudStatus = _statusText(_hud.state);
    _hudSub = _hud.stateStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _hudConnected = s == HudConnectionState.connected;
        _hudActive = s != HudConnectionState.disconnected;
        _hudStatus = _statusText(s);
      });
    });
  }

  @override
  void dispose() {
    _hudSub?.cancel();
    _ipCtl.dispose();
    _proxyCtl.dispose();
    _haUrlCtl.dispose();
    _haAgentCtl.dispose();
    _haTokenCtl.dispose();
    super.dispose();
  }

  String _statusText(HudConnectionState s) {
    final url = _hud.currentUrl ?? '';
    switch (s) {
      case HudConnectionState.connected:
        return 'Connected to $url (frame submitted ≠ physically displayed)';
      case HudConnectionState.connecting:
        return 'Connecting to $url ...';
      case HudConnectionState.reconnecting:
        return 'Connection lost (${_hud.lastError ?? 'no details'}). Retrying...';
      case HudConnectionState.error:
        return 'Failed: ${_hud.lastError ?? 'unknown error'}. Check the IP, that this device is on the '
            'same 2.4 GHz WiFi, and that the Egg is RUNNING (its screen shows its IP). Retrying in the background.';
      case HudConnectionState.discovering:
        return 'Discovering...';
      case HudConnectionState.disconnected:
        return 'Not connected';
    }
  }

  Future<void> _load() async {
    setState(() {
      // Load async below
    });
    _flipH = await SettingsStore.getFlipHorizontal();
    _flipV = await SettingsStore.getFlipVertical();
    _rotation = await SettingsStore.getRotation();
    _invert = await SettingsStore.getInvert();
    _threshold = await SettingsStore.getThreshold();
    _animSpeed = await SettingsStore.getAnimationSpeed();
    _screenTimeout = await SettingsStore.getScreenTimeout();
    _hudIp = await SettingsStore.getHudIp();
    _useCorsProxy = await SettingsStore.getUseCorsProxy();
    _proxyUrl = await SettingsStore.getProxyUrl();
    _keepAwake = await SettingsStore.getKeepAwake();
    _keepAliveInterval = await SettingsStore.getKeepAliveInterval();
    _haUrl = await SettingsStore.getHaUrl();
    _haUrlCtl.text = _haUrl;
    _haAgentId = await SettingsStore.getHaAgentId();
    _haAgentCtl.text = _haAgentId;
    _speechRate = await SettingsStore.getSpeechRate();
    _speechVolume = await SettingsStore.getSpeechVolume();
    _recLang = await SettingsStore.getRecognitionLanguage();
    _verbosity = await SettingsStore.getVerbosity();
    _pushToTalk = await SettingsStore.getPushToTalk();
    _haToken = (await SettingsStore.getHaToken()) ?? '';
    _haTokenCtl.text = _haToken;
    _ipCtl.text = _hudIp;
    _proxyCtl.text = _proxyUrl;
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _discover() async {
    setState(() => _hudStatus = 'Discovering...');
    final report = await HudDiscovery.discoverWithReport(lastKnownIp: _hudIp);
    if (!mounted) return;
    setState(() {
      _discovered = report.devices;
      _hudStatus = report.devices.isEmpty
          ? 'No HUD found. ${report.summary}'
          : 'Found ${report.devices.length} device(s). ${report.summary}';
    });
  }

  Future<void> _connectHud() async {
    String? url;
    if (_useCorsProxy) {
      url = _proxyUrl.trim();
    } else {
      url = HudConnection.hostToUrl(_hudIp);
      if (url == null) {
        // No IP entered: try to find the Egg before giving up.
        setState(() => _hudStatus = 'No IP entered. Looking for the HUD on the network...');
        final report = await HudDiscovery.discoverWithReport();
        if (!mounted) return;
        if (report.devices.isEmpty) {
          setState(() {
            _discovered = [];
            _hudStatus = 'Enter the HUD IP (shown on the glasses). ${report.summary}';
          });
          return;
        }
        final d = report.devices.first;
        _hudIp = d.ip;
        _ipCtl.text = d.ip;
        await SettingsStore.setHudIp(d.ip);
        url = d.wsUrl;
      }
    }
    if (url.isEmpty) {
      setState(() => _hudStatus = 'Enter HUD WebSocket URL first.');
      return;
    }
    // Status text is driven by the connection's state stream (see initState).
    final ok = await _hud.connect(url);
    if (ok) {
      // Send initial test frame to prove transport
      final enc = DisplayFrameEncoder();
      _hud.sendFrame(enc.checkerboardFrame());
    }
  }

  Future<void> _disconnectHud() async {
    await _hud.disconnect();
  }

  Future<void> _testHa() async {
    setState(() => _haStatus = 'Testing...');
    final client = HomeAssistantClient(baseUrl: _haUrl, token: _haToken, agentId: _haAgentId);
    final result = await client.testConnection();
    if (!mounted) return;
    setState(() => _haStatus = result.message);
  }

  void _applyTransform() {
    try {
      ref.read(displayRendererProvider).setTransform(DisplayTransform(
        flipHorizontal: _flipH,
        flipVertical: _flipV,
        rotation: _rotation,
        invert: _invert,
      ));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Display', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile(title: const Text('Flip Horizontal'), value: _flipH, onChanged: (v) async {
            setState(() => _flipH = v);
            await SettingsStore.setFlipHorizontal(v);
            _applyTransform();
          }),
          SwitchListTile(title: const Text('Flip Vertical'), value: _flipV, onChanged: (v) async {
            setState(() => _flipV = v);
            await SettingsStore.setFlipVertical(v);
            _applyTransform();
          }),
          ListTile(
            title: const Text('Rotation'),
            trailing: DropdownButton<int>(
              value: _rotation,
              items: [0, 90, 180, 270].map((r) => DropdownMenuItem(value: r, child: Text('$r°'))).toList(),
              onChanged: (v) async {
                setState(() => _rotation = v!);
                await SettingsStore.setRotation(v!);
                _applyTransform();
              },
            ),
          ),
          SwitchListTile(title: const Text('Invert'), value: _invert, onChanged: (v) async {
            setState(() => _invert = v);
            await SettingsStore.setInvert(v);
            _applyTransform();
          }),
          ListTile(
            title: const Text('Threshold (brightness simulation)'),
            subtitle: Slider(
              value: _threshold,
              min: 0.2,
              max: 1.0,
              onChanged: (v) async {
                setState(() => _threshold = v);
                await SettingsStore.setThreshold(v);
              },
            ),
          ),
          const Text(
            'Note: Software inversion/threshold does NOT control physical OLED electrical brightness. Hardware contrast requires firmware support.',
            style: TextStyle(fontSize: 11),
          ),
          ListTile(
            title: const Text('Animation Speed'),
            subtitle: Slider(
              value: _animSpeed,
              min: 0.2,
              max: 3.0,
              onChanged: (v) async {
                setState(() => _animSpeed = v);
                await SettingsStore.setAnimationSpeed(v);
              },
            ),
          ),
          ListTile(
            title: const Text('Screen Timeout (s)'),
            trailing: DropdownButton<int>(
              value: _screenTimeout,
              items: [10, 30, 60, 120].map((s) => DropdownMenuItem(value: s, child: Text('$s'))).toList(),
              onChanged: (v) async {
                setState(() => _screenTimeout = v!);
                await SettingsStore.setScreenTimeout(v!);
              },
            ),
          ),
          const Divider(),
          const Text('Calibration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(onPressed: () => _sendTest('checkerboard'), child: const Text('Checkerboard')),
              ElevatedButton(onPressed: () => _sendTest('black'), child: const Text('Black')),
              ElevatedButton(onPressed: () => _sendTest('white'), child: const Text('White')),
              ElevatedButton(onPressed: () => _sendTest('half'), child: const Text('Half')),
            ],
          ),
          const Divider(),
          const Text('Connection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextField(
            controller: _ipCtl,
            decoration: const InputDecoration(labelText: 'HUD IP (manual), e.g. 192.168.1.27', hintText: 'shown on the glasses screen'),
            onChanged: (v) async {
              _hudIp = v;
              await SettingsStore.setHudIp(v);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: _discover, icon: const Icon(Icons.search), label: const Text('Discover HUD'))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(onPressed: _hudActive ? _disconnectHud : _connectHud, icon: Icon(_hudActive ? Icons.link_off : Icons.link), label: Text(_hudActive ? 'Disconnect' : 'Connect'))),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _hudConnected ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(_hudStatus,
                style: TextStyle(
                  color: _hudConnected ? Colors.green : Colors.red,
                  fontSize: 12,
                )),
          ),
          for (final d in _discovered)
            ListTile(
              title: Text(d.displayName),
              trailing: ElevatedButton(
                onPressed: () async {
                  await SettingsStore.setHudIp(d.ip);
                  _ipCtl.text = d.ip;
                  setState(() => _hudIp = d.ip);
                },
                child: const Text('Use'),
              ),
            ),
          ExpansionTile(
            title: const Text('Provisioning Guide'),
            children: [Padding(padding: const EdgeInsets.all(8), child: Text(HudProvisioning.guideSteps))],
          ),
          const Divider(),
          const Text('CORS Proxy (Web only)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Optional. WebSockets are not subject to CORS; a browser tab can still connect directly to ws://<hud-ip>:81 from http://localhost. '
              'Use the proxy only if the page is served over https (browsers block ws:// from https pages) or the direct connection is blocked.'),
          SwitchListTile(
            title: const Text('Use CORS Proxy'),
            subtitle: const Text('Connect via ws://<pc-lan-ip>:8081/ws instead of direct ws://<hud-ip>:81'),
            value: _useCorsProxy,
            onChanged: (v) async {
              setState(() => _useCorsProxy = v);
              await SettingsStore.setUseCorsProxy(v);
            },
          ),
          TextField(
            controller: _proxyCtl,
            decoration: const InputDecoration(labelText: 'Proxy WebSocket URL (e.g. ws://192.168.1.50:8081/ws)'),
            onChanged: (v) async {
              _proxyUrl = v;
              await SettingsStore.setProxyUrl(v);
            },
          ),
          const Text(
            'Run: python tools/hud_cors_proxy.py <your-hud-ip> [port]\nThen set Proxy URL to ws://<your-pc-lan-ip>:<port>/ws',
            style: TextStyle(fontSize: 11),
          ),
          SwitchListTile(
            title: const Text('Keep Awake (always-on, background service)'),
            subtitle: const Text('Android foreground service keeps HUD WebSocket alive when screen is off. Requires notification permission.'),
            value: _keepAwake,
            onChanged: (v) async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _keepAwake = v);
              await SettingsStore.setKeepAwake(v);
              if (v) {
                final ok = await HudForegroundService.start();
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(ok ? 'Background service started. HUD will stay awake when screen is off.' : 'Background service not available on this platform (desktop/web).')),
                );
              } else {
                await HudForegroundService.stop();
              }
            },
          ),
          ListTile(
            title: const Text('Keep-alive Interval (s)'),
            trailing: DropdownButton<int>(
              value: _keepAliveInterval,
              items: [5, 10, 15, 20].map((s) => DropdownMenuItem(value: s, child: Text('$s'))).toList(),
              onChanged: (v) async {
                setState(() => _keepAliveInterval = v!);
                await SettingsStore.setKeepAliveInterval(v!);
              },
            ),
          ),
          const Divider(),
          const Text('EDITH / Hermes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextField(
            controller: _haUrlCtl,
            decoration: const InputDecoration(labelText: 'Home Assistant URL (e.g. http://192.168.1.30:8123)'),
            onChanged: (v) async {
              _haUrl = v;
              await SettingsStore.setHaUrl(v);
            },
          ),
          TextField(
            controller: _haAgentCtl,
            decoration: const InputDecoration(labelText: 'Conversation Agent ID (optional)'),
            onChanged: (v) async {
              _haAgentId = v;
              await SettingsStore.setHaAgentId(v);
            },
          ),
          TextField(
            controller: _haTokenCtl,
            decoration: const InputDecoration(labelText: 'HA Long-lived Token (secure storage)'),
            obscureText: true,
            onChanged: (v) async {
              _haToken = v;
              await SettingsStore.setHaToken(v);
            },
          ),
          ElevatedButton.icon(onPressed: _testHa, icon: const Icon(Icons.network_check), label: const Text('Test Connection')),
          Text(_haStatus),
          ListTile(
            title: const Text('Speech Rate'),
            subtitle: Slider(
              value: _speechRate,
              min: 0.0,
              max: 1.0,
              onChanged: (v) async {
                setState(() => _speechRate = v);
                await SettingsStore.setSpeechRate(v);
              },
            ),
          ),
          ListTile(
            title: const Text('Speech Volume'),
            subtitle: Slider(
              value: _speechVolume,
              min: 0.0,
              max: 1.0,
              onChanged: (v) async {
                setState(() => _speechVolume = v);
                await SettingsStore.setSpeechVolume(v);
              },
            ),
          ),
          ListTile(
            title: const Text('Recognition Language'),
            trailing: DropdownButton<String>(
              value: _recLang,
              items: ['en-US', 'mn-MN', 'zh-CN'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (v) async {
                setState(() => _recLang = v!);
                await SettingsStore.setRecognitionLanguage(v!);
              },
            ),
          ),
          ListTile(
            title: const Text('Verbosity'),
            trailing: DropdownButton<String>(
              value: _verbosity,
              items: ['brief', 'normal', 'detailed'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (v) async {
                setState(() => _verbosity = v!);
                await SettingsStore.setVerbosity(v!);
              },
            ),
          ),
          SwitchListTile(title: const Text('Push-to-talk'), value: _pushToTalk, onChanged: (v) async {
            setState(() => _pushToTalk = v);
            await SettingsStore.setPushToTalk(v);
          }),
          const Divider(),
          const Text('Audio Devices (phone OS)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('HUD Egg is display-only. Audio via phone OS. Bluetooth earbuds may have mic+speaker; some headphones are output-only.'),
          AudioDeviceStatus(),
          const Divider(),
          const Text('Interaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Touch, keyboard, voice, gestures, Bluetooth HID button configurable. Future hardware via replaceable adapter.'),
          InputTimingSettings(),
          const Divider(),
          const Text('Personalization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Dashboard layouts, character style, clock style, notification priorities, favorite tools.'),
          const Divider(),
          const Text('Power', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('HUD keep-awake, keep-alive, screen timeout, animation power-saving, background connection, low-battery warnings.'),
        ],
      ),
    );
  }

  void _sendTest(String kind) {
    final enc = DisplayFrameEncoder();
    List<int> frame;
    switch (kind) {
      case 'checkerboard':
        frame = enc.checkerboardFrame();
        break;
      case 'black':
        frame = enc.blackFrame();
        break;
      case 'white':
        frame = enc.whiteFrame();
        break;
      case 'half':
        frame = enc.halfFrame();
        break;
      default:
        frame = enc.blackFrame();
    }
    if (!_hudConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test frame "$kind" generated (${frame.length} bytes). Connect HUD first (Connection section).')),
      );
      return;
    }
    final ok = _hud.sendFrame(frame);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Sent "$kind" (${frame.length} bytes). Verify on OLED.' : 'Send failed — not connected.')),
    );
  }
}
