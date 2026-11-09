# GLAS — Egg HUD

Wearable smart-glasses HUD: a dumb remote display (HUD Egg) driven by a Flutter Brain App.

- **HUD Egg** — ESP32-C3 SuperMini + SSD1309 128×64 SPI OLED. Joins WiFi, receives 1024-byte binary frames over WebSocket, renders them, sleeps when idle.
- **Brain App (GLAS)** — Flutter app (Android/Windows/Web). Owns all state, renders to a 128×64 canvas, pushes frames to the Egg, handles mDNS discovery and auto-reconnect.
- **Controller** — ESP32 DevKit button via ESP-NOW to HUD Egg (no phone pairing). Optional wrist input.

## Wire protocol (frozen)

- WebSocket: `ws://hud.local:81` (or IP). No auth, no handshake payload.
- One binary message per frame, **exactly 1024 bytes**, no header.
- 128×64, 1bpp, SSD130x page layout: `buffer[(y/8)*128 + x]`, bit `(y%8)` = pixel on (LSB = top row of page).
- Any other length is dropped. The Egg never sends anything back on port 81.
- Controller input: separate WebSocket on port 82 (JSON button events from ESP-NOW controller).

## Layout

```
firmware/HUD/                    ESP32-C3 sketch (Arduino, multi-file)
firmware/Jarvis_Wrist_Controller/ ESP32 ESP-NOW button sketch
brain_app/                       Flutter app (GLAS)
tools/send_test_frames.py        PC test: sends checkerboard/half/white/black frames
tools/hud_cors_proxy.py          Optional proxy for https web builds
releases/GLAS-debug.apk          Android debug build (Git LFS)
```

## Build

```bash
# Firmware (CDCOnBoot=cdc is mandatory — GPIO20/21 are OLED RST/DC)
arduino-cli compile --fqbn esp32:esp32:esp32c3:CDCOnBoot=cdc firmware/HUD
arduino-cli upload -p <PORT> --fqbn esp32:esp32:esp32c3:CDCOnBoot=cdc firmware/HUD

# App
cd brain_app
flutter pub get
flutter test
flutter build apk --debug
```

## Test

```bash
python tools/send_test_frames.py 192.168.1.27   # by IP
python tools/send_test_frames.py hud.local      # by mDNS
```

Verify frames on the OLED — a socket send does not prove the display updated.

## Notes

- 2.4 GHz WiFi only (C3 has no 5 GHz). Keep the Egg close to the router (RSSI < -80 dBm causes association failures).
- Full-white frames draw peak current. `DISPLAY_CONTRAST 100` in `firmware/HUD/Config.h` avoids brownout on USB; add a 100–470µF cap across OLED VCC/GND for battery use.
- Never commit WiFi credentials.
