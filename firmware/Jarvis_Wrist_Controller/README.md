# Jarvis Palm Mouse

A Bluetooth (BLE) air mouse built on a standard **ESP32 DevKit** + MPU6050.
Tilt/twist your wrist to move the cursor, click the button to left-click,
long-press the button to pause/resume cursor tracking. Pairs as a normal
Bluetooth mouse — no custom drivers, no companion app required.

```
Jarvis_Wrist_Controller/
├── Jarvis_Wrist_Controller.ino
├── README.md
└── src/
    ├── Config.h
    ├── MPU6050Sensor.h / .cpp
    └── BLEController.h / .cpp
```

(The folder/`.ino` filenames are unchanged from earlier versions of this
project — rename both together if you want, just keep them matching, which
Arduino IDE requires.)

---

## 1. Wiring (standard ESP32 DevKitC / WROOM-32)

| MPU6050 pin | ESP32 DevKit pin |
|---|---|
| VCC | 3.3V |
| GND | GND |
| SDA | GPIO21 |
| SCL | GPIO22 |
| AD0 | GPIO4 |
| INT | not connected |
| XDA | not connected |
| XCL | not connected |

| Button | ESP32 DevKit pin |
|---|---|
| One leg | GPIO27 |
| Other leg | GND |

No external resistor needed — GPIO27 uses the internal pull-up
(`INPUT_PULLUP`); the button simply pulls the pin to GND when pressed.

INT/XDA/XCL stay unconnected — the firmware polls the sensor rather than
using interrupts or the MPU6050's auxiliary I2C bus.

---

## 2. Required libraries

| Library | Author | Purpose |
|---|---|---|
| Adafruit MPU6050 | Adafruit | MPU6050 driver |
| Adafruit Unified Sensor | Adafruit | Sensor event abstraction (dependency) |
| Adafruit BusIO | Adafruit | I2C/SPI abstraction (dependency) |
| **ESP32 BLE Mouse** | T-vK | BLE HID mouse emulation |

Install via Arduino IDE: Sketch → Include Library → Manage Libraries →
search **"ESP32 BLE Mouse"** (same author, T-vK, as the BLE Keyboard
library if you used an earlier version of this project — same install
pattern, same Bluedroid BLE backend, no NimBLE setup needed on a standard
ESP32 DevKit).

`Preferences.h` and `Wire.h` ship with the ESP32 Arduino core — no
separate install needed. (This version doesn't use LittleFS — there's no
gesture data to persist anymore.)

---

## 3. Arduino IDE setup

1. **Install the ESP32 board package**
   File → Preferences → "Additional Boards Manager URLs":
   `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   Then Tools → Board → Boards Manager → search "esp32" → install.
2. **Select the board**: Tools → Board → ESP32 Arduino → **ESP32 Dev Module**
3. **Upload Speed**: 921600 (drop to 115200 if you get upload errors).
4. **Drivers**: most DevKitC boards use a CP2102 or CH340 USB-serial chip;
   usually auto-installed on modern Windows/macOS/Linux.

---

## 4. Connecting it to your PC or phone (Bluetooth pairing)

The firmware already advertises itself as a standard **BLE HID mouse** —
once it's flashed and running, pairing it is exactly like pairing any
Bluetooth mouse. It shows up as **"Jarvis Palm Mouse"** (`BLE_DEVICE_NAME`
in `Config.h` if you want to rename it).

**Windows 10/11**
Settings → Bluetooth & devices → Add device → Bluetooth → select
"Jarvis Palm Mouse" from the list.

**macOS**
System Settings → Bluetooth → wait for "Jarvis Palm Mouse" to appear
under "Nearby Devices" → Connect.

**iOS / iPadOS**
Settings → Bluetooth → wait for it to appear under "Other Devices" → tap
to connect. (BLE HID mice work in iPadOS's pointer-supported apps; plain
iPhone iOS supports BLE mice too via the same Bluetooth pairing, cursor
appears system-wide on recent iOS versions.)

**Android**
Settings → Connected devices → Pair new device → select
"Jarvis Palm Mouse".

**Linux**
Settings → Bluetooth (or `bluetoothctl`: `scan on`, then `pair <MAC>`,
`connect <MAC>`) → select "Jarvis Palm Mouse".

A few things worth knowing:
- The device must be powered and past its startup calibration (see
  section 5) before it'll advertise — give it a couple seconds after
  power-up before searching for it.
- `status` in Serial Monitor shows `BLE connected: yes/no` if you want to
  confirm the link from the firmware side.
- Cursor movement/clicks sent while disconnected are silently dropped
  (`BLEController` no-ops) rather than queued — nothing to "catch up" on
  once you reconnect.
- Only one host can be connected at a time with this library (standard BLE
  HID behavior) — forget/disconnect on one device before pairing to
  another.

---

## 5. First boot

1. Flash the sketch, open Serial Monitor at **115200 baud**.
2. On boot: MPU6050 init → automatic gyro/accel calibration (**keep the
   device still and roughly level** for ~1-2 seconds) → BLE advertising
   starts as **"Jarvis Palm Mouse"**.
3. Pair it (section 4).
4. Tilt/twist your wrist — the cursor should move. Click the button —
   should register as a left-click.

---

## 6. How it works

- **Cursor tracking runs continuously**, independent of the button — that's
  inherent to how an air mouse has to work (unlike the old hold-to-activate
  gesture design, the sensor can't just sleep until you press something,
  since motion needs to be tracked live). This does mean higher power draw
  than a button-gated design; use long-press to pause tracking when you're
  not actively using it if battery life matters to you.
- Every `MOUSE_SAMPLE_INTERVAL_MS` (12ms / ~80Hz default), the firmware
  reads the gyro's angular velocity on two axes and turns it directly into
  a relative cursor delta: `dx/dy = angularVelocity × dt × sensitivity`.
- **Click**: press and release the button within `MOUSE_LONG_PRESS_MS`
  (450ms default) → left-click.
- **Long-press**: hold past that threshold → toggles cursor tracking
  on/off. This is the "lift the mouse off the pad" trick — pause tracking,
  reposition your hand/wrist comfortably, resume tracking, without the
  cursor jumping across the screen while you do it.
- A small deadzone (`MOUSE_DEADZONE_DPS`) ignores tiny hand tremor so the
  cursor sits genuinely still when your wrist is still.
- **Continuous drift correction**: gyro bias shifts slightly over time
  (mainly with temperature), which the one-time startup calibration can't
  account for — that's what causes a slow cursor creep even when the
  device is sitting still. Whenever a channel's reading is already small
  (under `MOUSE_STILLNESS_DPS`), the firmware treats that as evidence of
  where true zero currently is and slowly re-centers on it. Real motion
  stays well above that threshold, so it's never damped by this. Send
  `rezero` over Serial (device held still) to flush accumulated drift
  instantly instead of waiting for it to adapt on its own.

---

## 7. Fixing "cursor moves the wrong way" — one place, no code hunting

A wrist has three independent rotations, and a 2D cursor only uses two of
them — whichever one you *don't* map simply won't move the cursor, which
is exactly what you want for "twisting my forearm shouldn't move the
mouse":

| Motion | Description | Default channel |
|---|---|---|
| **Yaw** | panning your hand left/right, like shaking your head "no" | `gz` → horizontal |
| **Pitch** | tilting your hand up/down, like nodding | `gy` → vertical |
| **Roll** | twisting your forearm inward/outward, like turning a doorknob | unmapped (`gx`) |

Everything about this lives in four lines at the top of the **MOUSE
MOTION** section of `Config.h`:

```cpp
#define MOUSE_GYRO_CHANNEL_X   gz   // which raw axis drives left/right
#define MOUSE_GYRO_CHANNEL_Y   gy   // which raw axis drives up/down
#define MOUSE_INVERT_X          0   // flip left/right
#define MOUSE_INVERT_Y          0   // flip up/down
```

The defaults above are a guess based on a board mounted flat on top of the
wrist with its long edge along the forearm — your specific mount may wire
yaw/pitch/roll to a different `gx`/`gy`/`gz` than this guess. If cursor
movement tracks forearm twisting (roll) instead of up/down or left/right,
that means whichever channel is currently assigned to `MOUSE_GYRO_CHANNEL_X`
or `_Y` is actually your roll axis on this mount — try the channel that
isn't currently used instead.

If the cursor moves vertically when you meant horizontally (or vice
versa), swap which channel (`gx`, `gy`, or `gz`) is assigned to
`MOUSE_GYRO_CHANNEL_X` vs `_Y`. If an axis moves the *right* way but
backwards, flip its `MOUSE_INVERT_*` from `0` to `1`. That's it — nothing
else in the firmware encodes an assumption about how the device is
mounted on your wrist, so there's no other file to go digging through.

A quick way to figure out which channel is which for your mount: run
`debug` in Serial Monitor, then tilt/twist the device in just the motion
you want to be "horizontal" and watch which of `gx/gy/gz` moves — that's
the one to assign to `MOUSE_GYRO_CHANNEL_X`.

---

## 8. Troubleshooting

**MPU6050 not found at boot**
- Confirm SDA→GPIO21, SCL→GPIO22, AD0→GPIO4, VCC→3.3V.
- Lower `I2C_CLOCK_HZ` in `Config.h` from 400000 to 100000 if your wiring
  is jumper wires on a breadboard rather than a soldered connection.

**Button doesn't seem to do anything**
- Check `status` in Serial Monitor while holding it — it should read
  "pressed". If it never changes, verify the button's other leg actually
  reaches GND and that you're on GPIO27 (or whatever you changed
  `PIN_BUTTON` to).

**Cursor drifts on its own even when the device is still**
- The firmware continuously self-corrects small drift (see section 6) —
  give it a couple seconds to adapt, or send `rezero` in Serial Monitor
  while holding the device still to flush it instantly.
- If drift is large/fast rather than a slow creep, run `recalibrate`
  instead (device still and level) — that's likely a bigger bias jump than
  the continuous correction is meant to handle, e.g. right after the
  device has physically warmed up.
- `status` shows the current `Drift bias (dps)` estimate if you want to
  watch it settle.
- Raise `MOUSE_DEADZONE_DPS` slightly if it's small persistent jitter
  rather than a steady one-direction drift.

**Cursor is too fast / too slow / feels different on each axis**
- Adjust `MOUSE_SENSITIVITY_X` / `MOUSE_SENSITIVITY_Y` in `Config.h`
  independently.

**Cursor moves the wrong direction/axis**
- See section 7 — it's a four-line `Config.h` change, not a code change.

**Cursor doesn't move at all**
- Check `status` — is BLE connected? Is tracking "engaged" (not paused
  from a long-press)? Run `debug` and watch the `gx/gy/gz` numbers move as
  you tilt the device, to confirm the sensor itself is alive.

**BLE won't pair, or pairs but the cursor/clicks don't arrive**
- On a standard ESP32 DevKit the default Bluedroid backend just works —
  no NimBLE setup needed. If pairing still fails, forget the device on
  your PC/phone and re-pair after a fresh power cycle.
- Only one host can be connected at a time — disconnect/forget on any
  other paired device first.

---

## 9. Tuning reference (all in `src/Config.h`)

| Constant | Effect |
|---|---|
| `BUTTON_DEBOUNCE_MS` | Button debounce window |
| `MOUSE_LONG_PRESS_MS` | Press duration boundary between click and long-press (toggle tracking) |
| `MOUSE_ENGAGED_AT_BOOT` | Whether cursor tracking starts on or paused |
| `MOUSE_SAMPLE_INTERVAL_MS` | Cursor update rate |
| `MOUSE_GYRO_CHANNEL_X` / `_Y`, `MOUSE_INVERT_X` / `_Y` | Orientation — see section 7 |
| `MOUSE_SENSITIVITY_X` / `_Y` | Cursor speed per axis |
| `MOUSE_DEADZONE_DPS` | Angular velocity below which motion is ignored as noise |
| `MOUSE_STILLNESS_DPS` / `MOUSE_BIAS_ADAPT_RATE` | How "still" a reading must look to be learned as the new zero, and how fast the drift estimate adapts |
| `MOUSE_MAX_STEP_PX` | Soft cap on cursor movement per tick (prevents "teleporting") |
| `LPF_ALPHA_GYRO` / `LPF_ALPHA_ACCEL` | Sensor smoothing (lower = smoother but laggier) |
