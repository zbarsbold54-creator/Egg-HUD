# EDITH Glasses OS — Brain App

Central orchestrator for the HUD Egg (ESP32-C3 + SSD1309 128×64) and Hermes via Home Assistant.
EDITH is the assistant display name. Hermes on ZimaOS is the AI backend (unchanged).

## Quick Start

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows   # or -d chrome
```

See `docs/SETUP_GUIDE.md` for full setup, provisioning, HA/Hermes, and troubleshooting.
See `docs/FEATURE_REPORT.md` for what is implemented vs tested.

## Architecture

- `lib/display/` — 128×64 renderer, 1024-byte encoder, transforms, simulator
- `lib/connectivity/hud/` — mDNS/DNS discovery, WebSocket, provisioning
- `lib/connectivity/home_assistant/` + `hermes/` — real HA APIs, no second intelligence
- `lib/features/` — dashboard, assistant, navigation, music, notifications, translator, teleprompter, chess, sound, tools, settings
- `lib/input/` — touch, keyboard, voice, gestures, future hardware adapter

Frozen protocol: `ws://hud.local:81`, binary 1024 bytes, SSD130x page layout. Do not change.
