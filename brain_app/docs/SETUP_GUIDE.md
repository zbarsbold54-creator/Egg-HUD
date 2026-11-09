# EDITH Glasses OS — Setup Guide

EDITH is the assistant display name. Hermes on ZimaOS remains the AI backend.
This guide covers installation, HUD pairing, Home Assistant, and testing.

## 1. Install the Brain App

### Prerequisites
- Flutter 3.44.8+ (verified: 3.44.8, Dart 3.12.2)
- Windows: Visual Studio 2022+ with Desktop C++ workload
- Android: Android Studio + SDK (not installed on this machine — see §7)
- Linux: Flutter Linux desktop toolchain

### Build
```bash
cd brain_app
flutter pub get
flutter analyze
flutter test
flutter run -d windows   # desktop simulator + full UI
flutter run -d chrome    # web (verified build)
```

Windows release build requires **Developer Mode** (Settings → System → For developers → Developer Mode ON) for plugin symlinks. This is an OS setting, not a code issue.

## 2. Pair / Use the HUD Egg over Wi-Fi

The HUD Egg is a dumb 128×64 display. It joins Wi-Fi, advertises `hud.local`, and receives 1024-byte binary frames over WebSocket port 81.

### First-time provisioning
1. Power the HUD Egg (USB or battery).
2. On your phone/computer, connect Wi-Fi to AP `HUD-Setup-XXXX`.
3. Open `http://192.168.4.1` in a browser.
4. Enter your home **2.4 GHz** SSID and password in the form. Tap Connect.
5. The Egg saves credentials (up to 5 networks) and reboots to station mode.
6. Reconnect your phone to your normal Wi-Fi.
7. In EDITH app: Settings → Connection → Discover HUD (or enter IP manually).

**Never paste Wi-Fi passwords into chat. Never log passwords.**

### Connect in the app
- Settings → Connection → Discover HUD → Use (or manual IP entry)
- The app connects to `ws://<ip>:81`, sends a test frame, and starts rendering.
- Distinguish: discovered → connected → frame submitted → physically displayed (external test only).

## 3. Connect Home Assistant

EDITH talks to Hermes **via Home Assistant**. Do not create a second intelligence.

1. In Home Assistant, create a **long-lived access token** (Profile → Long-Lived Access Tokens).
2. In EDITH app: Settings → EDITH / Hermes:
   - Home Assistant URL: e.g. `http://192.168.1.30:8123` (local network only — **do not expose HA publicly**)
   - Conversation Agent ID: optional (leave blank to auto-discover)
   - Token: paste the long-lived token (stored in secure storage, never in logs)
3. Tap **Test Connection**.
   - If no conversation agent is found, expose Hermes as a conversation agent in HA, or set the agent ID manually.
   - Do not invent a Hermes endpoint. The app uses only supported HA APIs: `GET /api/`, `POST /api/conversation/process`, WebSocket `/api/websocket`.

## 4. Configure STT and TTS

- Settings → EDITH / Hermes:
  - Speech Rate / Volume: sliders
  - Recognition Language: `en-US`, `mn-MN`, `zh-CN`
  - Verbosity: brief / normal / detailed
  - Push-to-talk: ON (default). Continuous listening only if explicitly enabled.
- Uses OS default audio output — Bluetooth earbuds work via normal OS pairing.
- No fake wake-word detection. Offline vs online recognition is shown in the assistant screen.

## 5. Configure Display Orientation

Settings → Display:
- Flip Horizontal / Vertical (independent)
- Rotation: 0° / 90° / 180° / 270°
- Invert, Threshold (brightness simulation), Animation Speed, Screen Timeout
- Live preview in the HUD Simulator (`/simulator` route)

**Note:** Software inversion/threshold does NOT control physical OLED electrical brightness. Hardware contrast requires firmware support.

## 6. Test the Actual Glasses

1. Connect HUD Egg (see §2).
2. Settings → Calibration → send Checkerboard, Black, White, Half frames.
3. Verify on the physical OLED: checkerboard must look correct (not sheared/inverted), half frame must be left-white/right-black.
4. Full-white on USB first, then on battery (brownout test — do not change brownout detector settings).
5. Idle test: after 30s with no frames, screen sleeps; next frame wakes instantly; WS connection survives sleep.
6. **Do not interpret a successful WebSocket send as proof the OLED displayed the frame.** Confirm visually.

## 7. Android SDK (missing on this machine)

`flutter doctor` shows: `[X] Android toolchain - Unable to locate Android SDK.`

To build Android APK:
1. Install Android Studio from https://developer.android.com/studio
2. On first launch, install SDK components.
3. `flutter doctor --android-licenses` (accept licenses)
4. `flutter build apk --release`

Do not install large environments without owner approval — this step requires explicit confirmation.

## 8. Troubleshoot Disconnections

- **HUD not discovered:** mDNS is often blocked on Android. Use manual IP entry. Check both devices are on the same 2.4 GHz network.
- **WebSocket connects but screen blank:** Verify frame is exactly 1024 bytes (Settings → Calibration). Wrong length is silently dropped by firmware.
- **Screen sleeps immediately:** Keep-alive is OFF. Enable Settings → Connection → Keep Awake, or send frames more often than every 30s.
- **HA connection fails:** Check URL is reachable on local network, token is valid, and Hermes is exposed as a conversation agent. Do not expose HA to the public internet.
- **STT/TTS not working:** Check microphone permission, Bluetooth earbuds are paired at OS level, and recognition language is supported on your device.

## 9. Hardware Compatibility

- HUD Egg: ESP32-C3 SuperMini + SSD1309 128×64 SPI OLED (frozen protocol, 1024 bytes, port 81)
- Controller: **Deferred.** Do not flash or depend on Palm Mouse firmware. App is fully usable without it (touch, keyboard, voice, gestures).
- Glasses battery: **Unavailable.** Firmware has no `BATTERY_ADC_PIN` configured. App shows phone battery only, never confuses the two.
- Audio: OS default output (Bluetooth earbuds). No custom audio stack.
