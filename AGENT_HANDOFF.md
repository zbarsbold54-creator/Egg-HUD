# Jarvis — Project Handoff + Agent Task Prompt

You are taking over a half-finished hardware/software project from a previous
AI session. Part 1 is the full state of the project. Part 2 is your task.
Read both fully before running anything.

The owner (Barsaa) is the product designer/architect and directs AI tools to
write implementation code. Work autonomously on everything that doesn't need
physical hardware, and stop to ask at the points marked **[PAUSE]**.

Working directory = the folder containing this file. Layout:

```
Jarvis_Project/
├── AGENT_HANDOFF.md              <- this file
├── BrainApp_build_prompt.md      <- full spec for the Flutter app (Task 6)
└── firmware/
    ├── HUD/                      <- ESP32-C3 HUD Egg sketch (Arduino, multi-file)
    └── Jarvis_Wrist_Controller/  <- ESP32 DevKit BLE mouse sketch (Arduino)
```

Arduino requires each sketch folder name to match its `.ino` name — do not
rename `HUD/` or `Jarvis_Wrist_Controller/`.

---

# PART 1 — PROJECT STATE

## 1.1 What "Jarvis" is

A wearable smart-glasses HUD system with three components:

1. **HUD Egg** — ESP32-C3 SuperMini + SSD1309 128×64 SPI OLED (the display
   mounted in the glasses). A dumb remote monitor: joins WiFi, receives
   bitmap frames over WebSocket, shows them, sleeps when idle.
2. **Controller ("Jarvis Palm Mouse")** — wrist-worn ESP32 DevKit + MPU6050
   gyro + one button. A standard **BLE HID mouse** (relative dx/dy + left
   click). It is NOT a keyboard and NOT a custom GATT device.
3. **Brain App** — Flutter app (phone/tablet/laptop/desktop). Owns all state,
   renders screens to a 128×64 canvas, pushes frames to the HUD Egg, runs the
   AI assistant. **Not built yet — only a spec exists** (`BrainApp_build_prompt.md`).

## 1.2 Parts list

| Part | Used for | Notes |
|---|---|---|
| ESP32-C3 SuperMini **with built-in 0.42" OLED** (72×40, I2C) | HUD Egg MCU | The built-in OLED is **unused/abandoned** (see 1.4 pin conflict). Ignore it in firmware. |
| SSD1309 128×64 SPI OLED (transparent, 4-wire SPI, 3.3V) | Glasses display | Main display. |
| Battery (LiPo) for the HUD Egg | Portable power | Exact cell/charger/regulator not documented — ask the owner if relevant. |
| ESP32 DevKitC / WROOM-32 | Controller MCU | Classic ESP32, not C3. |
| MPU6050 (GY-521 style) | Controller gyro | I2C. |
| Push button | Controller click / long-press | Internal pull-up. |
| Bluetooth earbuds | Audio for AI assistant | Plain OS-level pairing; no firmware involved. |

## 1.3 Pinouts (authoritative)

### HUD Egg — ESP32-C3 SuperMini ↔ SSD1309 (SPI)

| OLED pin | ESP32-C3 GPIO |
|---|---|
| VCC | 3.3V |
| GND | GND |
| DIN (MOSI) | GPIO6 |
| CLK (SCK) | GPIO4 |
| CS | GPIO7 |
| DC | GPIO21 |
| RST | GPIO20 |

### Controller — ESP32 DevKit ↔ MPU6050 + button

| Signal | ESP32 DevKit pin |
|---|---|
| MPU6050 VCC | 3.3V |
| MPU6050 GND | GND |
| MPU6050 SDA | GPIO21 |
| MPU6050 SCL | GPIO22 |
| MPU6050 AD0 | GPIO4 (firmware drives LOW → I2C addr 0x68) |
| MPU6050 INT / XDA / XCL | not connected |
| Button leg 1 | GPIO27 |
| Button leg 2 | GND (internal pull-up, active-low) |

## 1.4 Hardware gotchas to respect

- **GPIO6 conflict (resolved by dropping a feature):** the SuperMini's
  built-in OLED is typically on I2C GPIO5/GPIO6 (SDA/SCL — verify on the
  actual board). GPIO6 is also the SSD1309 MOSI. Decision made: the built-in
  display is not used. Never initialize it or call `Wire.begin` on those pins
  in the HUD sketch.
- **GPIO20/21 are the C3's UART0 pins, and they're wired to OLED RST/DC.**
  `HUD.ino` calls `Serial.begin()`. If Serial routes to UART0 instead of USB,
  its TX will drive GPIO21 (OLED DC) and corrupt the display. The build
  **must** use USB-CDC serial: FQBN option `CDCOnBoot=cdc`
  (Arduino IDE: Tools → "USB CDC On Boot: Enabled"). Always compile/flash the
  HUD with that option.
- **Battery brownout (already mitigated in firmware):** a full-white frame
  draws peak current and made the ESP32 brownout-reset on battery (fine on
  USB). Fix applied: `DISPLAY_CONTRAST 153` (~60%) in `firmware/HUD/Config.h`,
  applied via `setContrast()` in `DisplayDriver::begin()`. If resets persist,
  lower it (try ~100) and/or the owner adds a 100–470 µF capacitor across the
  OLED VCC/GND. Don't "fix" brownouts by disabling the brownout detector.
- 2.4 GHz WiFi only (C3 has no 5 GHz).

## 1.5 HUD firmware (firmware/HUD) — current state

Arduino sketch, multi-file. Libraries: **U8g2** (olikraus), **WebSockets**
(Links2004/arduinoWebSockets). Built-ins: WiFi, WebServer, ESPmDNS, Preferences.

| File | Job |
|---|---|
| `HUD.ino` | State machine: BOOT → WIFI_CONNECT → PROVISIONING or RUNNING |
| `Config.h` | Pins + constants (contrast, timeouts, ports) |
| `DisplayDriver` | U8g2 `SSD1309_128X64_NONAME0_F_4W_HW_SPI`, SPI remapped via `SPI.begin(SCK,-1,MOSI,CS)`; `writeFrame()` memcpy's 1024 bytes into the buffer + `sendBuffer()` |
| `WiFiManager` | STA only; up to 5 networks in NVS (`Preferences` ns `wifi`); scans and joins the first known SSID in range |
| `Provisioning` | Temp open AP `HUD-Setup-XXXX`, HTTP on 192.168.4.1:80; `GET /` form, `POST /connect` (form fields `ssid`, `password`) saves + reboots |
| `MdnsAdvertiser` | `hud.local`, service `_ws._tcp` port 81 |
| `WSServer` | WebSocketsServer on **port 81**; binary msg of exactly 1024 B = frame |
| `PowerManager` | After 30 s with no frame: display sleep + WiFi modem-sleep; instant wake on next frame |
| `OfflineScreen` | When no WS client: shows uptime + IP (battery line stubbed "n/a" — no ADC pin wired) |

Status: compiled and flashed by the owner; **the display works over USB**
(owner confirmed). One earlier compile error (static/extern on
`webSocketEvent`) was already fixed. The rest of the pipeline (WiFi join,
provisioning, WS frames end-to-end, sleep/wake) has **not been verified on
hardware**.

### Wire protocol (frozen — do not change)

- WebSocket client → `ws://hud.local:81` (or IP). No handshake payload, no auth.
- One **binary** message per frame, **exactly 1024 bytes**, no header.
- 128×64, 1 bpp, SSD130x page layout: `buffer[(y/8)*128 + x]`, bit `(y%8)`
  set = pixel on (**LSB = top row of the page**).
- Any other length is silently dropped by the firmware.
- The Egg never sends anything back over the socket.
- Frame updates are full-frame only (dirty-rect is a possible future change).

### Known defects / gaps in the HUD firmware (fix in Task 4)

1. **Provisioning retry can't scan.** `Provisioning::begin()` sets
   `WiFi.mode(WIFI_AP)`, but `HUD.ino` then periodically calls
   `connectToBestKnownNetwork()` (which needs STA scanning/joining) from the
   PROVISIONING state. AP-only mode can't do this. Use `WIFI_AP_STA` while
   provisioning, and return to `WIFI_STA` when provisioning ends.
2. **Re-entry bug.** If WiFi drops while RUNNING, state goes back to
   WIFI_CONNECT and `enterRunning()` later calls `MdnsAdvertiser::begin()` and
   `WsServer.begin()` again. Make those idempotent (init once, or tear down
   properly).
3. **No wrong-password feedback.** A bad password just silently fails and
   re-enters setup mode. Show a short message on the OLED.
4. **No Serial diagnostics.** Add concise `Serial.print` logging (state
   transitions, SSID chosen, IP, mDNS result, WS connect/disconnect, bad-frame
   length). There is no secondary display; Serial over USB-CDC is the debug
   channel.
5. **Battery readout** on the offline screen is a stub (`BATTERY_ADC_PIN -1`).
   Leave it unless the owner wires a divider.

## 1.6 Controller firmware (firmware/Jarvis_Wrist_Controller) — current state

Provided by the owner as-is; treat as working unless compile/hardware testing
proves otherwise. Libraries: **Adafruit MPU6050**, **Adafruit Unified Sensor**,
**Adafruit BusIO**, **ESP32 BLE Mouse** (T-vK; `BleMouse.h`). Built-ins:
Wire, Preferences.

Behavior: BLE HID mouse advertised as **"Jarvis Palm Mouse"**; gyro → relative
cursor at ~80 Hz; short press = left click; long press (450 ms) = toggle
cursor tracking; startup gyro calibration (device must be still ~1–2 s);
continuous drift correction; Serial commands `status`, `debug`, `rezero`,
`recalibrate` at 115200. All tuning/orientation lives in `src/Config.h`.

Risk: the T-vK BLE Mouse library has had compile problems on some arduino-esp32
core 3.x versions (BLE callback signature changes). If it fails to compile,
diagnose properly (try a maintained fork or a compatible core version) and
tell the owner what you changed — don't silently downgrade the core in a way
that breaks the HUD build.

Pairing is **OS-level Bluetooth**, like any mouse. The Brain App contains no
Controller BLE code.

## 1.7 Brain App (Flutter) — state

Not started. Full spec in `BrainApp_build_prompt.md` (HUD protocol, provisioning
flow, Render Engine, module list, build order). Key decisions already made:
- Controller = cursor + click only → UI must be fully operable by pointing and
  clicking (chess moves = click source square, click destination). No Morse /
  keystroke input path.
- AI assistant: STT → tool-calling LLM → tool → TTS, via the OS's default
  Bluetooth audio.
- Background keep-alive of the HUD WebSocket is the hard cross-platform part.

## 1.8 Dev environment facts

- Owner is on **Windows** (sketch path seen: `C:\Users\HiTech\Downloads\HUD`)
  and has used the **Arduino IDE**, so the ESP32 core and the two HUD
  libraries may already be installed under the shared Arduino data dir
  (`%LOCALAPPDATA%\Arduino15`, `Documents\Arduino\libraries`). arduino-cli uses
  the same dirs by default — check before re-installing.
- Owner runs a ZimaOS home server; not needed for this task.

---

# PART 2 — YOUR TASK

Goal: get both firmwares building and flashed, verify the HUD end to end, then
build the Brain App. Use `arduino-cli` for everything Arduino-related.

## Ground rules

- Never change the wire protocol (1.5) or the pinouts (1.3) without asking.
- Don't flash a board until the owner confirms which device is plugged in.
  Flashing the wrong sketch onto the wrong board is the main way to waste time
  here.
- Never hardcode or commit WiFi credentials. Never print them in logs.
- Keep fixes minimal and explain each one in your final report.
- If something is genuinely ambiguous (hardware, wiring, power), ask — don't
  guess.

## Task 1 — Find or install arduino-cli

1. Check whether it already exists, in this order:
   - `arduino-cli version`
   - `where arduino-cli` (Windows) / `which arduino-cli`
   - Arduino IDE 2.x bundles one; look under the IDE install dir, e.g.
     `%LOCALAPPDATA%\Programs\Arduino IDE\resources\app\lib\backend\resources\`
     (verify the real path — don't assume)
   - `winget list` / `winget search arduino-cli`
2. If found, use it (and note its path). If it's not on PATH but exists on
   disk, call it by full path or add its folder to the **user** PATH and tell
   the owner you did.
3. If **not found**, install it:
   - Preferred: `winget install` with the package ID you find from
     `winget search arduino-cli` (verify the ID; don't trust memory).
   - Fallback: download the latest `Windows_64bit` zip from the official
     GitHub releases page (`github.com/arduino/arduino-cli/releases`), extract
     to `%USERPROFILE%\arduino-cli\`, and add that folder to the user PATH.
   - Verify with `arduino-cli version`.
4. `arduino-cli config init` if no config exists. Add the ESP32 board index URL
   `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   (don't duplicate if already present), then `arduino-cli core update-index`.

## Task 2 — Core and libraries

1. `arduino-cli core list` — if `esp32:esp32` is missing, install it.
2. `arduino-cli lib list` first; install only what's missing:
   - `U8g2`
   - `WebSockets` (author Markus Sattler / Links2004)
   - `Adafruit MPU6050`, `Adafruit Unified Sensor`, `Adafruit BusIO`
   - `ESP32 BLE Mouse` (T-vK). If it's not in the Library Manager index,
     install from its GitHub repo (`arduino-cli lib install --git-url ...`,
     enabling `library.enable_unsafe_install` if required) and tell the owner.
3. Note the installed esp32 core version in your report.

## Task 3 — Compile both sketches (no hardware needed)

- HUD (note the CDC option — it is mandatory, see 1.4):
  `arduino-cli compile --fqbn esp32:esp32:esp32c3:CDCOnBoot=cdc firmware/HUD`
- Controller:
  `arduino-cli compile --fqbn esp32:esp32:esp32 firmware/Jarvis_Wrist_Controller`

Fix compile errors with minimal changes. Confirm `DISPLAY_CONTRAST` is present
in `firmware/HUD/Config.h` and applied in `DisplayDriver::begin()` (it should
be).

## Task 4 — Fix the known HUD defects

Implement items 1–4 from section 1.5 ("Known defects"), keeping the existing
module structure and state machine. Re-compile after. Don't add features
beyond those four.

## Task 5 — Flash and verify (hardware)

**[PAUSE 1]** Ask the owner to connect the **glasses / HUD Egg (ESP32-C3
SuperMini)** by USB. Then:

1. `arduino-cli board list` → identify the port; confirm with the owner that
   the detected board is the HUD Egg before flashing.
2. `arduino-cli upload -p <PORT> --fqbn esp32:esp32:esp32c3:CDCOnBoot=cdc firmware/HUD`
   - If the C3 isn't detected or upload fails: hold the BOOT button while
     plugging in USB (download mode), retry.
3. Open the serial monitor (`arduino-cli monitor -p <PORT> -c baudrate=115200`)
   and watch the state transitions from your new logging.
4. If no WiFi is known, the Egg opens `HUD-Setup-XXXX`. **[PAUSE 2]** Ask the
   owner to provision it (join the AP, open `http://192.168.4.1`, enter their
   2.4 GHz SSID/password). Never ask them to paste the password to you.
5. Once it's on the network, confirm `hud.local` resolves (or read the IP from
   serial) and run an end-to-end test with a small script (Python
   `websockets` or Node `ws`) that sends **binary 1024-byte frames** to
   `ws://hud.local:81`:
   - a checkerboard (verifies bit/page layout — rows must look correct, not
     sheared or inverted),
   - a left-half-white / right-half-black frame,
   - a **full-white frame** (this is the one that used to brownout on battery;
     test it on USB first, then **[PAUSE 3]** ask the owner to repeat on
     battery power and report whether it resets),
   - a wrong-length frame (must be ignored, screen unchanged).
6. Verify idle behavior: after 30 s of no frames the screen sleeps; the next
   frame wakes it instantly; the WS connection survives sleep.
7. Keep the test script in the repo (`tools/send_test_frames.py`) — the Brain
   App work will reuse it as a protocol reference.

## Task 6 — Controller

**[PAUSE 4]** Ask the owner to connect the **Controller (ESP32 DevKit)** by
USB. Confirm the board, then:

1. `arduino-cli upload -p <PORT> --fqbn esp32:esp32:esp32 firmware/Jarvis_Wrist_Controller`
2. Serial monitor at 115200; confirm MPU6050 init + calibration (device must
   be held still). Ask the owner to pair "Jarvis Palm Mouse" in OS Bluetooth
   settings and report: cursor direction/axes correct? clicks work? If axes
   are wrong, adjust only the four orientation defines in `src/Config.h`
   (see the controller README §7).

## Task 7 — Brain App (Flutter)

1. `flutter --version` / `flutter doctor`. If Flutter isn't installed, **stop
   and ask the owner** before installing it (it's large).
2. Build the app by following `BrainApp_build_prompt.md` exactly, in its
   suggested build order. The HUD protocol section is authoritative and
   matches Part 1 above. Ask before inventing any protocol detail.
3. Start with: mDNS discovery → WebSocket connect → send the static test frame
   → confirm on the real glasses, before building any screens.
4. Use the owner's target set (Windows desktop first is fine for fast
   iteration; Android/iOS support comes with the Background Service work).

## Definition of done / final report

Report back with:
- arduino-cli: found or installed, path, version; esp32 core version.
- Compile status of both sketches, and every code change you made (file + why).
- HUD hardware test results for each test frame, the idle-sleep test, and the
  battery full-white result.
- Controller pairing/axis results.
- Brain App status vs. its build order, and what's blocked.
- Anything you noticed that looks wrong with the hardware or wiring.
