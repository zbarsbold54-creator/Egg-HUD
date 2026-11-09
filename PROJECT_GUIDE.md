# EDITH / GLAS — Complete Project Guide

> Wearable smart-glasses HUD. A dumb remote display (HUD Egg) driven by a Flutter Brain App (GLAS). EDITH is the assistant display name; Hermes on ZimaOS is the AI backend.

---

## 1. What this project is

Three parts:

| Part | Hardware / Software | Job |
|------|---------------------|-----|
| **HUD Egg** | ESP32-C3 SuperMini + SSD1309 128x64 SPI OLED | Dumb remote monitor. Joins WiFi, receives bitmap frames over WebSocket, shows them, sleeps when idle. No decisions. |
| **Brain App (GLAS)** | Flutter (Android primary, Windows/Linux/Web) | Owns all state. Renders screens to a 128x64 canvas, pushes frames to the Egg, runs STT/TTS, talks to Hermes via Home Assistant. |
| **Controller** | ESP32 DevKit + button (GPIO27) | Physical button to ESP-NOW to HUD Egg to WebSocket to App. No phone pairing. (Paused — phone touch is primary.) |

The phone is the brain. The glasses are a screen. The controller is a button.

```
CONTROLLER (ESP32 DevKit, GPIO27 button)
    |
    | ESP-NOW (2.4 GHz, same channel as HUD WiFi)
    |
HUD EGG (ESP32-C3 + SSD1309 OLED)
    |  ws://hud.local:81  (display, 1024-byte binary frames)
    |  ws://hud.local:82  (input, JSON button events)
    |
BRAIN APP (GLAS, Flutter)
    |
    | Home Assistant REST/WS
    |
HERMES (ZimaOS)
```

---

## 2. Hardware

### 2.1 HUD Egg — ESP32-C3 SuperMini to SSD1309 (SPI)

| OLED pin | ESP32-C3 GPIO |
|----------|---------------|
| VCC | 3.3V |
| GND | GND |
| DIN (MOSI) | GPIO6 |
| CLK (SCK) | GPIO4 |
| CS | GPIO7 |
| DC | GPIO21 |
| RST | GPIO20 |

- Built-in 0.42 inch OLED (72x40, I2C on GPIO5/6) is **unused**. Never call Wire.begin on those pins.
- GPIO20/21 are UART0 pins wired to OLED RST/DC. Build **must** use USB-CDC: CDCOnBoot=cdc. Otherwise Serial TX corrupts the display.
- Contrast DISPLAY_CONTRAST 100 in firmware/HUD/Config.h. Full-white at 153 brownout-resets on USB. Add 100-470uF cap across OLED VCC/GND for battery.
- 2.4 GHz WiFi only (C3 has no 5 GHz).

### 2.2 Controller — ESP32 DevKit to button

| Signal | ESP32 DevKit pin |
|--------|------------------|
| Button leg 1 | GPIO27 |
| Button leg 2 | GND (internal pull-up, active-low) |

- MPU6050 (SDA GPIO21, SCL GPIO22, AD0 GPIO4) is wired but **unused** in ESP-NOW mode (gyro cursor deferred).
- Power: USB or LiPo. ESP32 WiFi peaks can brownout on weak USB — use a short thick cable, direct PC port, or powered hub.

---

## 3. Wire protocol (FROZEN — do not change)

### 3.1 Display channel (port 81)

- WebSocket client to ws://hud.local:81 (or IP). No handshake payload, no auth.
- One **binary** message per frame, **exactly 1024 bytes**, no header.
- 128x64, 1 bpp, SSD130x page layout: buffer[(y/8)*128 + x], bit (y%8) set = pixel on (**LSB = top row of the page**).
- Any other length is silently dropped by firmware.
- The Egg never sends anything back over this socket.
- Full-frame only (no dirty-rect).

App side:

```dart
bool sendFrame(List<int> bytes) {
  if (bytes.length != AppConfig.frameBytes) return false; // 1024
  channel.sink.add(Uint8List.fromList(bytes));
  return true;
}
```

Firmware side:

```cpp
bool DisplayDriver::writeFrame(const uint8_t* data, size_t len) {
  if (len != FRAME_BYTES) return false; // 1024
  memcpy(_u8g2.getBufferPtr(), data, FRAME_BYTES);
  _u8g2.sendBuffer();
  return true;
}
```

### 3.2 Input channel (port 82)

- Separate WebSocket: ws://hud.local:82.
- JSON text messages (HUD to App only):
  - {"v":1,"type":"button_down","seq":42,"ts":12345,"controller":1}
  - {"v":1,"type":"button_up","seq":43,"ts":12445,"durationMs":100,"controller":1}
  - {"v":1,"type":"status","status":"CONNECTED","code":3}
- Sequence numbers detect duplicates/missing events. App ignores seq <= lastSeq for button events.
- Display WS (81) and input WS (82) reconnect independently. Input disconnect never interrupts display.

### 3.3 ESP-NOW packet (controller to HUD)

Fixed-size struct, 24 bytes, well under ESP-NOW 250-byte limit:

```cpp
#pragma pack(push, 1)
struct EspNowPacket {
  uint8_t version;      // 1
  uint8_t type;         // 1=BEACON, 2=ANNOUNCE, 3=ACK, 4=DOWN, 5=UP, 6=HEARTBEAT, 7=STATUS
  uint8_t controllerId; // 1
  uint8_t channel;      // HUD WiFi channel (e.g. 11)
  uint32_t seq;         // sequence number
  uint32_t timestampMs; // millis() at send
  uint32_t durationMs;  // press duration (UP only)
  uint8_t buttonState;  // 0 released, 1 pressed
  uint8_t status;       // 0..5 (DISCONNECTED..ERROR)
  uint8_t mac[6];       // sender MAC
};
#pragma pack(pop)
```

Discovery flow:
1. HUD joins WiFi, inits ESP-NOW on the AP channel, broadcasts beacons every 2s.
2. Controller scans channels 1-13 (or sits on HUD channel), listens for beacons.
3. Controller registers HUD MAC as peer, sends ANNOUNCE.
4. HUD ACKs. Both remember peer. Heartbeat every 5s. Timeout 15s to rescan.

---

## 4. HUD firmware (firmware/HUD/)

Arduino sketch, multi-file. Libraries: U8g2, WebSockets. Built-ins: WiFi, ESPmDNS, Preferences.

| File | Job |
|------|-----|
| HUD.ino | State machine: BOOT to WIFI_CONNECT to PROVISIONING or RUNNING |
| Config.h | Pins, contrast 100, ports 81/82, heartbeat, timeouts |
| DisplayDriver | U8g2 SSD1309_128X64_NONAME0_F_4W_HW_SPI, writeFrame() memcpy 1024B + sendBuffer() |
| WiFiManager | STA only, 5 networks in NVS, scan + join, hidden-SSID fallback, disconnect-reason logging |
| Provisioning | AP HUD-Setup-XXXX, HTTP 192.168.4.1:80, POST /connect saves + reboots |
| MdnsAdvertiser | hud.local, _ws._tcp:81 + _input._tcp:82 (restarted on every enterRunning) |
| WSServer | Port 81, binary 1024B = frame, heartbeat, client count |
| InputWSServer | Port 82, JSON button events, status broadcast |
| EspNowBridge | ESP-NOW receive, beacon broadcast, peer tracking |
| PowerManager | 30s idle to screen sleep. Radio modem-sleep only when display client connected AND no controller. |
| OfflineScreen | No WS client: uptime + IP |

State machine (HUD.ino):

```cpp
enum class HudState { BOOT, WIFI_CONNECT, PROVISIONING, RUNNING };
// WIFI_CONNECT: connectToBestKnownNetwork(true) to RUNNING or PROVISIONING
// PROVISIONING: Provision.loop() + retry scan when no phone on AP
// RUNNING: WsServer.loop() + InputWs.loop() + EspNowBridge.loop()
//          + Power.loop() + Offline.render() + WiFi loss to WIFI_CONNECT
```

Build (CDC is mandatory):

```bash
arduino-cli compile --fqbn esp32:esp32:esp32c3:CDCOnBoot=cdc firmware/HUD
arduino-cli upload -p <PORT> --fqbn esp32:esp32:esp32c3:CDCOnBoot=cdc firmware/HUD
```

---

## 5. Controller firmware (firmware/Jarvis_Wrist_Controller/)

ESP-NOW button only. No BLE, no gyro.

- Button GPIO27, active-low, 25ms debounce.
- WiFi STA (no AP join), ESP-NOW init on HUD channel.
- Sends BUTTON_DOWN/BUTTON_UP with seq + duration. Heartbeat 5s. Timeout 15s to rescan.
- Serial at 115200: [CTRL] EDITH controller boot, searching for HUD..., [CTRL] HUD found ch=11, [CTRL] CONNECTED.

Build:

```bash
arduino-cli compile --fqbn esp32:esp32:esp32 firmware/Jarvis_Wrist_Controller
# Flash needs manual download mode: hold BOOT, tap EN, release BOOT
arduino-cli upload -p <PORT> --fqbn esp32:esp32:esp32 firmware/Jarvis_Wrist_Controller
```

---

## 6. Brain App (brain_app/)

Flutter 3.44, Dart 3.12, Riverpod.

### 6.1 Providers (lib/connectivity/hud/hud_providers.dart)

```dart
final hudConnectionProvider = Provider<HudConnection>((ref) {
  final c = HudConnection();
  ref.onDispose(() => unawaited(c.dispose()));
  return c;
});
final displayRendererProvider = Provider<DisplayRenderer>((ref) {
  final renderer = DisplayRenderer();
  renderer.setSink((bytes) => ref.watch(hudConnectionProvider).sendFrame(bytes));
  // Apply saved flip/rotation on launch
  return renderer;
});
final hudInputConnectionProvider = Provider<HudInputConnection>((ref) { ... });
final inputStateMachineProvider = Provider<InputStateMachine>((ref) { ... });
```

- **One shared HudConnection** for the whole app (was: private instance in Settings that died with the screen).
- **Foreground service:** `connectedDevice|microphone|location` types. Permissions: FOREGROUND_SERVICE + CONNECTED_DEVICE + MICROPHONE + LOCATION. Qualifying perm for connectedDevice: CHANGE_WIFI_MULTICAST_STATE / CHANGE_WIFI_STATE / CHANGE_NETWORK_STATE (all declared). Runtime computes type set from granted perms, starts only from visible UI, restarts with extra types when voice/nav starts. No autoRunOnBoot — on boot/restart posts "tap to resume voice/nav" notification.
- **Auto-connect** on launch: saved IP first, else discovery once. Re-discovers if saved IP stale.
- **Lifecycle:** AppLifecycle registered as WidgetsBindingObserver. On resume to ensureConnected() + forceFrame().

### 6.2 HUD connection (hud_connection.dart)

- Single reconnect owner (_scheduleReconnect), generation counter (stale callbacks ignored).
- connect() returns true/false, real error in lastError. No unhandled Completer errors.
- sendFrame: drops unless connected, latest-frame-wins, ~15 fps pacing (66ms min interval), no unbounded queue.
- Display clients: HUD accepts multiple WS clients (count, not bool). App-side latest wins (new connect closes old channel).
- 8s ready timeout. Backoff 1s to 30s capped. disconnect() stops retrying.
- hostToUrl(): "192.168.1.27" to "ws://192.168.1.27:81", empty to null (no ws://:81).

### 6.3 Discovery (hud_discovery.dart)

Order: DNS-SD PTR to SRV to A to hostname A (hud.local) to system resolver to last saved IP to manual. Every IP verified with Socket.connect (2s timeout). InternetAddress.lookup is last-resort only (Android rarely resolves .local). NsdManager not used — multicast_dns covers all platforms with one code path.

- **PTR to SRV to A** (was: A on instance name, never worked). Uses SRV port.
- Android: CHANGE_WIFI_MULTICAST_STATE + MulticastLock via MainActivity.kt channel.
- Web: kIsWeb guard to "discovery not supported in browser, enter IP".
- Every IP verified with isReachable (TCP connect) before success.
- Reasons surfaced in Settings (timeout, no multicast, unreachable).

### 6.4 Input (hud_input_connection.dart, hud_input_provider.dart)

- WebSocket client to port 82. Independent reconnect (backoff 1-30s).
- Decodes JSON, validates seq (drops duplicates), emits HudInputEvent.
- HudInputProvider feeds InputStateMachine:
  - button_down to onButtonDown() (starts 2s exit timer)
  - button_up to onButtonUpWithDuration(duration) (preserves Morse timing)
- Status: DISCONNECTED/SEARCHING/CONNECTING/CONNECTED/RECONNECTING/ERROR to dashboard + Settings. SEARCHING means no ESP-NOW peer yet (normal at boot). Seq resets on reconnect AND on status CONNECTED AND on interim rule (seq <=4 and seq < lastSeq means reboot). Duplicates (== or -1) rejected. Firmware sends status CONNECTED only on new input WS client connect, NOT on controller re-announce.

### 6.5 Input state machine (input_state_machine.dart)

| Mode | Short | Double | 2s hold |
|------|-------|--------|---------|
| Normal | next | select | exit |
| Morse | dot (<200ms) | dash (>=200ms) | exit (no char, 2s hold) |
| Voice | toggle | — | exit |

- Double-press waits for window (doesn't fire short first).
- 2s exit has priority in every mode, never generates Morse char.
- Timing configurable in Settings (persisted, applied on launch).

---

## 7. Display rendering — how the glasses change between apps

### 7.1 Pipeline

```
Screen (Flutter) draws into Framebuffer (128x64, 1bpp)
    to DisplayTransform (flipH/V, rotation, invert, threshold)
    to DisplayFrameEncoder (1024 bytes, SSD130x page layout)
    to HudConnection.sendFrame() to ws://hud.local:81
    to HUD WSServer to DisplayDriver.writeFrame() to OLED
```

- DisplayRenderer holds the canvas, sink (shared connection), transform, keep-alive timer.
- Only sends when canvas changed (hash comparison) unless forceFrame().
- AppLifecycle calls forceFrame() on reconnect/resume to restore the current screen.

### 7.2 Per-app display

Each screen draws into the shared canvas via DisplayRenderer.canvas, then calls requestFrame():

- **Dashboard:** EDITH orb + status (HUD/CTRL/WiFi) + module grid. HUD shows compact status.
- **Always-on (3 tiers):**
  - Tier 1 (active): redraw every 10s, full brightness.
  - Tier 2 (idle 60s no input): pixel-shift 4px cycle + dim (every other row cleared) to avoid burn-in. Frames continue, firmware stays awake.
  - Tier 3 (sleep N min, default 5, configurable): send one blank frame, then stop sending. Firmware sleeps after 30s no-frame. Any input/interaction calls notifyInput() to forceFrame() and resume.
  - Firmware wakes on frame (onFrameReceived), NOT on controller press directly. Controller press wakes app via input WS, app sends frame, firmware wakes.
- **Music:** Bars animate while playing (visualizer demo). HUD shows track + bars.
- **Chess:** Board with unicode pieces. HUD shows monochrome board.
- **Assistant:** EDITH character state (idle/listening/thinking/speaking). HUD shows state text.
- **Navigation:** Turn-by-turn + distance/ETA. HUD shows next turn.
- **Settings:** Connection status, flip/rotation toggles. HUD shows IP + state.

Switching apps = drawing a new canvas + requestFrame(). No protocol change. The HUD just renders the latest 1024-byte frame.

### 7.3 Orientation

Glasses mount may be sideways/upside-down. Settings to Display:

- **Flip Horizontal / Flip Vertical / Rotation (0/90/180/270) / Invert**
- Saved via SettingsStore, applied to DisplayRenderer.setTransform() on launch and live on change.
- Default rotation is **90 degrees** (glasses mounted sideways).

```dart
renderer.setTransform(DisplayTransform(
  flipHorizontal: await SettingsStore.getFlipHorizontal(),
  flipVertical: await SettingsStore.getFlipVertical(),
  rotation: await SettingsStore.getRotation(),
  invert: await SettingsStore.getInvert(),
));
```

---

## 8. Screens

| Screen | Route | What it does | Backend |
|--------|-------|--------------|---------|
| Dashboard | / | EDITH orb, real HUD/CTRL status, 10 modules | — |
| Assistant | /assistant | STT to HA to Hermes to TTS, interrupt, requestId guards | HA URL + token in Settings |
| Navigation | /navigation | GPS stream + OSRM route steps (configurable endpoint, foot profile default) | Location permission + network |
| Music | /music | Real playback (SoundHelix sample) + real phone volume + bars | Internet (sample URL) |
| Notifications | /notifications | Real POST_NOTIFICATIONS request. Mirroring needs NotificationListenerService (stubbed behind setting, not implemented) | Android 13+ permission |
| Translator | /translator | STT + language select. Engine not configured (honest message) | Needs ML Kit/REST |
| Teleprompter | /teleprompter | Script, speed, play/pause, position preserved | — |
| Chess | /chess | Full rules (chess package), point+click, unicode pieces | — |
| Sound | /sound | Mic/output devices via OS APIs | — |
| Tools | /tools | Stopwatch, calc, notes, clock | — |
| Settings | /settings | HUD connect/discover, flip/rotation, HA config, timing, audio | — |

---

## 9. Build, flash, test

```bash
# Firmware
arduino-cli compile --fqbn esp32:esp32:esp32c3:CDCOnBoot=cdc firmware/HUD
arduino-cli compile --fqbn esp32:esp32:esp32 firmware/Jarvis_Wrist_Controller

# App
cd brain_app
flutter pub get
flutter analyze
flutter test          # 50 tests
flutter build apk --debug   # 175MB debug
flutter build apk --release # 52MB release, signed CN=GLAS (glas-release.jks, gitignored)

**APK checksums (SHA-256):**
- GLAS-debug.apk: 68b47b167e1e0bcc38036a683f0d295bacc0168e871cfcf2f10abec154949ce5
- GLAS-release.apk: 149d54f20051f28e13a6c26aa3f2c688d4b4b210a2666dd5e44102fc91271172
- GLAS-release-nocleartext.apk: 6647a1172aec3a52e51261e7aa5bf62bbc6c70f8cffced485dd9a6c1fd28be84

**Keystore backup:** `brain_app/android/glas-release.jks` + `key.properties` are gitignored. Back them up offline (USB + password manager). Losing them means new keystore = new app identity (users must uninstall/reinstall). Passwords are in key.properties only (never in docs).
```

PC test (no app needed):

```bash
python tools/send_test_frames.py 192.168.1.27   # by IP
python tools/send_test_frames.py hud.local      # by mDNS
# Sends checkerboard, half, full-white, wrong-length (ignored), black.
# Verify on OLED — socket send does not prove display updated.
```

LAN APK download (no GitHub/LFS):

```bash
# PC serves releases/GLAS-debug.apk on LAN
python -m http.server 8080 --directory releases --bind 0.0.0.0
# Phone (same WiFi): http://192.168.1.20:8080/GLAS-release.apk
# Serve only on trusted LAN. Stop the server after installing (Ctrl+C).
```

---

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| App won't connect | Wrong IP, 5 GHz WiFi, client isolation | Use 2.4 GHz, same subnet, IP from serial ([HUD] state: RUNNING ip=...) |
| hud.local fails, IP works | mDNS blocked | Use IP. Check multicast, Android lock (already in app) |
| Display upside down | Orientation | Settings to Flip Vertical / Rotation 90 |
| Full-white resets | Brownout | Contrast 100 (already), better USB, 100-470uF cap |
| Controller reboots | USB power droop | Short thick cable, direct port, powered hub, cap |
| Controller won't flash | Not in download mode | Hold BOOT, tap EN, release BOOT |
| APK "problem with file" | GitHub LFS pointer | Use LAN link, not GitHub |
| Music bars fake | Visualizer demo | Real playback is SoundHelix sample; bars are demo |
| Volume doesn't change | Was fake | Now real (AudioManager) |
| App screens "don't work" | Need setup | Navigate: allow location. Assistant: set HA URL/token. Translate: no engine |

---

## 11. Frozen constraints

- Display protocol: port 81, binary, 1024 bytes, 128x64, SSD130x layout. **Do not change.**
- Pinouts: HUD (6/4/7/21/20), Controller (GPIO27 button). **Do not change.**
- No WiFi credentials in code, logs, or git.
- No Hermes reconfiguration. No invented HA endpoints.
- No flashing without owner approval. No wiring changes without approval.
