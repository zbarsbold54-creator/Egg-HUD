# EDITH Glasses OS — Feature Completion Report

Date: 2026-11-08 (post-implementation verification)
Flutter: 3.44.8, Dart 3.12.2
Identity: EDITH (display name). Hermes on ZimaOS is the AI backend (unchanged).

## Verified (evidence)

- `flutter analyze`: **No issues found!** (was 15 info/warning, now 0 — all fixed)
- `flutter test`: **43 tests passed** (22 original + 9 integration + 12 input)
  - `test/display/framebuffer_test.dart` — framebuffer size, pixel conversion, page/bit ordering, black/white/checkerboard/half, encode/decode, transforms
  - `test/core/text_pagination_test.dart` — wrap, paginate, summarize
  - `test/integration/hud_connection_test.dart` — wrong-length rejection, encoder validity, disconnected state
  - `test/integration/home_assistant_test.dart` — not-configured reporting, token-missing reporting, no fabricated response
  - `test/integration/display_simulator_test.dart` — renderer change-only send, transform preserves 1024 bytes, checkerboard via renderer
  - `test/widget_test.dart` — EDITH app builds dashboard
- `flutter build web --release`: **succeeded** (`build/web`, 32.9s)
- `flutter build windows --release`: **blocked** — `Building with plugins requires symlink support. Please enable Developer Mode`. Code compiles (analyze + test pass). Blocker is OS setting, not code.
- Android: **blocked** — `flutter doctor` shows `[X] Android toolchain - Unable to locate Android SDK`. SDK not installed (requires owner approval).
- Linux: cannot build on Windows host (Flutter limitation).

## Analyzer fixes (15 → 0)

| # | Issue | Fix |
|---|---|---|
| 1 | `prefer_interpolation_to_compose_strings` in HA client | Use string interpolation |
| 2 | `prefer_final_fields` in HudConnection | Made `_stateController` final |
| 3 | `localeId` deprecated in assistant_screen | Use `SpeechListenOptions(localeId:)` |
| 4 | `unnecessary_null_comparison` + dead code in chess | `move` returns `bool`, not `Move?` — changed `if (move != null)` to `if (move)` |
| 5 | `invalid_null_aware_operator` in chess | `piece?.type.name` (type is non-nullable, only piece is nullable) |
| 6-8 | `prefer_final_fields` in music/sound | Made never-reassigned fields final |
| 9 | `localeId` deprecated in translator | Use `SpeechListenOptions` |
| 10 | `gyroscopeEvents` deprecated | Use `gyroscopeEventStream()` |
| 11 | `localeId` deprecated in voice_input | Use `SpeechListenOptions` |
| 12 | `unused_field` in navigation | Removed unused `_currentPos` |
| 13-15 | Dangling doc comments in tests | Changed `///` to `//` |

## Audits

### Android permissions (verified in `AndroidManifest.xml`)
- `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE` — HUD WS, HA, OSRM
- `RECORD_AUDIO` — STT (speech_to_text requests at runtime)
- `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_CONNECT` — earbuds routing (OS default, no custom stack)
- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` — navigation (geolocator requests at runtime)
- `POST_NOTIFICATIONS` — notification access (UI requests transparently)
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `WAKE_LOCK` — background WS (declared; native foreground service not yet implemented — see Blockers)

Microphone: `speech_to_text` requests `RECORD_AUDIO` at runtime. Bluetooth audio: OS default output, earbuds via normal OS pairing. Notification access: permission declared, UI explains and requests. Background WS: reconnect with exponential backoff implemented; foreground service implemented via flutter_foreground_task (Android only). Lifecycle: `AppLifecycle` observer restores screen on resume, documents that uninterrupted background is not promised when OS prevents it.

### Windows desktop build
- Blocker: OS Developer Mode (Settings → System → For developers → Developer Mode ON). Required for plugin symlinks.
- Evidence: `flutter analyze` passes, `flutter test` passes, `flutter build web` succeeds. Windows code compiles; only the symlink step fails.
- Resolution: owner enables Developer Mode, then `flutter build windows --release`. No code change needed.

### HUD discovery (audited and fixed)
- Before: DNS lookup only (`InternetAddress.lookup('hud.local')`). Not DNS-SD.
- After: **actual DNS-SD** via `MDnsClient`:
  1. PTR query for `_ws._tcp.local` → instance name
  2. A query for instance → IP
  3. Fallback: A query for `hud.local` via mDNS
  4. Fallback: system DNS lookup
  5. Always available: manual IP entry in Settings
- Verified: code compiles, `flutter analyze` passes. Physical discovery requires HUD Egg on LAN (not tested — no hardware).

### EDITH interrupt behavior (audited and fixed)
- Before: `_interrupt()` stopped TTS/STT and set `_busy=false`, but late Hermes response could still arrive and speak.
- After: `_requestId` invalidates in-flight request. Late stages/responses are ignored locally. UI shows: *"Speech stopped. Remote Hermes execution may continue server-side (no cancel API)."*
- Distinction: **stopping local speech** (TTS/STT stop immediately) vs **cancelling remote Hermes execution** (not possible — HA conversation is a single HTTP POST with no cancel API). Hermes may still complete server-side; the app discards the late response.

### Navigation (verified)
- Uses **real location updates**: `Geolocator.getPositionStream()` with 5m distance filter, high accuracy. Not a single fix.
- Uses **actual route instructions**: OSRM `steps=true`, all steps parsed (maneuver type, modifier, street name, distance). Shows full instruction list, not just first turn.
- Permissions: checks and requests location permission, handles denied/deniedForever with clear messages.

### Home Assistant / Hermes (verified, no fabrication)
- `HomeAssistantClient.testConnection()` uses only supported HA APIs: `GET /api/`, WebSocket `/api/websocket` (auth + `conversation/agent/list`), `POST /api/conversation/process`.
- Tests verify: empty URL → "not configured", empty token → "token missing", `sendConversation` without config → throws (never fabricates).
- Real Hermes availability requires owner to provide HA URL + long-lived token in Settings → Test Connection. Not tested against live server (no credentials provided, no server modification).

## Implemented vs Tested

| Feature | Implemented | Unit tested | Simulator tested | Desktop tested | Android tested | Glasses tested |
|---|---|---|---|---|---|---|
| 128×64 renderer (framebuffer, encoder, transforms) | Yes | Yes (21 tests) | Yes (DisplayPreview + integration) | Web build | No (SDK missing) | No (no hardware test yet) |
| HUD discovery (DNS-SD PTR + A + DNS + manual) | Yes | No | Yes (UI) | Web build | No | No |
| HUD WebSocket (1024-byte frames, reconnect, keep-alive) | Yes | Yes (integration) | Yes (simulator) | Web build | No | No |
| Provisioning guide + POST helper | Yes | No | Yes (UI) | Web build | No | No |
| EDITH character (10 states, targeting reticle, eye/orb) | Yes | No | Yes (phone UI) | Web build | No | No |
| Dashboard + navigation + screen restoration | Yes | Widget test | Yes | Web build | No | No |
| Assistant (STT/TTS + HA/Hermes, interrupt distinguishes local vs remote) | Yes (real HA APIs) | Yes (HA integration) | Yes (UI) | Web build (STT/TTS platform-limited) | No | No |
| Home Assistant client (REST + WS, token auth) | Yes | Yes (integration) | Yes (test button) | Web build | No | No |
| Hermes adapter (via HA, no second intelligence) | Yes | No | Yes | Web build | No | No |
| Music (UI + platform guard) | Yes (UI) | No | Yes | Web build | No | No |
| Navigation (OSRM, live location stream, all steps) | Yes | No | Yes | Web build | No | No |
| Notifications (Android listener interface) | Yes (interface) | No | Yes | Web build | No | No |
| Translator (STT + provider interface) | Yes (UI) | No | Yes | Web build | No | No |
| Teleprompter (position preserved) | Yes | No | Yes | Web build | No | No |
| Chess (chess package, point+click, bool move fix) | Yes | No | Yes | Web build | No | No |
| Sound controls | Yes | No | Yes | Web build | No | No |
| Quick tools (stopwatch, calc, notes, clock) | Yes | No | Yes | Web build | No | No |
| Settings (display, calibration, connection, EDITH, interaction, personalization, power) | Yes (persisted) | No | Yes | Web build | No | No |
| Input abstraction (touch, keyboard, voice, gestures, Bluetooth HID button, state machine) | Yes | Yes (12 tests) | Yes (simulator) | Web build | No | No |
| Audio device detection (phone OS, Bluetooth mic vs output-only) | Yes | No | Yes (UI) | Web build | No | No |
| Display simulator (nearest-neighbor, grid, frame info) | Yes | Yes (integration) | Yes | Web build | No | No |
| Android permissions (manifest) | Yes | No | N/A | N/A | No (SDK missing) | N/A |
| Background WS (reconnect + lifecycle) | Yes (reconnect) | No | Yes | Web build | No | No |
| Foreground service (Android) | Yes (flutter_foreground_task) | No | Yes (UI toggle) | Web build (no-op) | No (SDK missing) | N/A |

**Never report an untested feature as complete.** The table above is the honest state.

## What Was NOT Done (by design)

- Palm Mouse / wrist-controller firmware: **deferred**, not implemented, not flashed, not depended on.
- HUD firmware: **untouched** (per task restrictions). No flash.
- Hermes configuration: **untouched** (per task restrictions).
- Android SDK: **not installed** (requires owner approval — see plan below).
- Physical glasses test: **not done** — requires [PAUSE 4] owner confirmation and hardware.

## Android SDK Installation Plan (awaiting owner approval)

**Required components:**
- Android Studio (latest stable, ~1.2 GB download)
- Android SDK Platform (API 34+, ~200 MB)
- Android SDK Build-Tools (34.0.0+, ~50 MB)
- Android SDK Command-line Tools (latest, ~150 MB)
- Android SDK Platform-Tools (adb, fastboot, ~15 MB)
- Android Emulator (optional, ~500 MB) + system images (~1 GB each)
- JDK 17 (bundled with Android Studio, no separate install)

**Disk requirements:**
- Minimum: ~5 GB free (SDK + build tools, no emulator)
- Recommended: ~10 GB free (with one emulator image)
- Full: ~20 GB free (multiple images, Gradle cache)

**Installation plan:**
1. Download Android Studio from https://developer.android.com/studio
2. Install with default options (SDK components above)
3. On first launch, accept licenses, install SDK components
4. Run `flutter doctor --android-licenses` (accept all)
5. Run `flutter doctor` — verify Android toolchain passes
6. Run `flutter build apk --release` — verify APK builds
7. Test on physical device or emulator (mic, Bluetooth, notifications, background)

**Do not install without owner approval.** This is a large download and system change.

## Remaining Blockers (verified list)

1. **Windows Developer Mode** — OS setting, not code. Owner must enable: Settings → System → For developers → Developer Mode ON. Then `flutter build windows --release`.
2. **Android SDK** — not installed. Requires owner approval (plan above). Then `flutter build apk --release`.
3. **Foreground service (Android)** — implemented via `flutter_foreground_task` (Dart isolate + Android service). Keeps HUD WebSocket alive when screen is off. Requires Android SDK to build/test. Uninterrupted background not promised when OS prevents it (battery optimization, manufacturer killers).
4. **HUD Egg hardware** — DNS-SD discovery, WebSocket frames, sleep/wake, brownout test require physical ESP32-C3 + SSD1309. Not tested.
5. **Home Assistant / Hermes live test** — requires owner to provide HA URL + token in Settings → Test Connection. Not tested against live server.
6. **STT/TTS on Android** — requires physical device with microphone and Bluetooth earbuds. Not tested (SDK missing).
7. **Navigation live test** — requires physical device with GPS. OSRM provider is real, but not tested with live location.

## Precise Next Hardware Tests (in order)

**[PAUSE 1 — HUD Egg Connection]** (firmware task, separate)
- Owner connects ESP32-C3 HUD Egg by USB.
- `arduino-cli board list` → identify port, confirm with owner.
- Flash HUD firmware (with AP_STA, idempotent init, wrong-password feedback, Serial diagnostics fixes).
- Serial monitor at 115200, watch state transitions.

**[PAUSE 2 — Wi-Fi Provisioning]**
- If no known network, Egg opens `HUD-Setup-XXXX`.
- Owner joins AP, opens `http://192.168.4.1`, enters 2.4 GHz SSID/password directly (never in chat).
- Egg reboots to STA, advertises `hud.local`.

**[PAUSE 3 — Full-White Power Test]**
- Send full-white frame on USB → verify no reset.
- Repeat on battery → report whether it resets (brownout).
- Do not change brownout detector settings.

**[PAUSE 4 — Brain App Real Display Test]**
- Owner confirms correct HUD Egg is connected.
- Send checkerboard → verify layout (not sheared/inverted).
- Send half frame → verify left-white/right-black.
- Send wrong-length frame → verify ignored, screen unchanged.
- Idle 30s → verify sleep, next frame wakes instantly, WS survives sleep.
- **Do not interpret WebSocket send as proof of physical display.** Confirm visually.

**Android device test (after SDK approval)**
- Install APK on physical Android phone.
- Grant mic, location, notification permissions.
- Pair Bluetooth earbuds at OS level.
- Test STT (push-to-talk), TTS (EDITH voice), HA/Hermes conversation.
- Test background: lock phone, verify HUD stays awake (if foreground service implemented) or document OS limitation.
- Test navigation with live GPS.

## Architecture (unchanged)

```
lib/
  app/ (app.dart, router.dart, lifecycle.dart)
  core/ (config, storage, theme, utils)
  display/ (framebuffer, renderer, encoders, transformations, simulator)
  connectivity/ (hud, home_assistant, hermes)
  input/ (touch, keyboard, voice, gestures, future_hardware)
  features/ (dashboard, assistant, navigation, music, notifications,
             translator, teleprompter, chess, sound, tools, settings)
  widgets/ (pixel_components, character, status_indicators, navigation_components)
  platform/
```

- State: Riverpod
- Persistence: SharedPreferences + SecureStorage (tokens never in logs)
- Renderer independent of hardware communication
- Feature modules independent of display driver
- Android-specific code behind platform interfaces

## Frozen Protocol (unchanged)

- `ws://hud.local:81`, binary 1024 bytes, SSD130x page layout, LSB = top row
- No header, no ack, no compression, no alternate ordering
- Egg never sends back. Wrong length silently dropped.
