# HUD Firmware (ESP32-C3 + SSD1309)

Remote bitmap monitor. No decision-making on this device — it connects,
receives frames, displays them, and sleeps aggressively when idle.

## Wiring

| OLED Pin      | ESP32-C3 GPIO |
|---------------|---------------|
| VCC           | 3.3V          |
| GND           | GND           |
| DIN (MOSI)    | GPIO6         |
| CLK (SCK)     | GPIO4         |
| CS             | GPIO7         |
| DC             | GPIO21        |
| RST            | GPIO20        |

No secondary display — dropped due to a GPIO6 conflict with the SuperMini's
built-in 0.42" OLED (which uses GPIO5/6 for I2C).

## Arduino IDE setup

1. Board: **ESP32C3 Dev Module** (install via Boards Manager: "esp32" by
   Espressif Systems).
2. Libraries (Library Manager):
   - **U8g2** by olikraus
   - **WebSockets** by Markus Sattler (Links2004/arduinoWebSockets)
   - `Preferences`, `WiFi`, `WebServer`, `ESPmDNS` ship with the ESP32 core —
     no install needed.
3. Open `HUD.ino` — the other `.h`/`.cpp` files in this folder show up as
   tabs automatically. Compile and flash.

## First boot / provisioning

On first boot (or if no known WiFi network is in range), the device opens
a temporary open AP named `HUD-Setup-XXXX`. Connect the Brain App's host
device to that AP, then:

```
POST http://192.168.4.1/connect
Content-Type: application/x-www-form-urlencoded

ssid=YourNetwork&password=YourPassword
```

On success the device saves the credentials (up to 5 networks are
remembered) and reboots into station mode. It'll auto-pick whichever
known network is in range on future boots.

Once connected, the device advertises itself at **`hud.local`** and opens
a WebSocket server on **port 81**.

## Frame protocol (v1 — full frame)

Send a **binary WebSocket message, exactly 1024 bytes**, per update.

- 128×64 pixels, 1 bit per pixel
- Layout: native SSD130x page-addressing format — 8 pages of 128 bytes,
  each byte a vertical 8-pixel column strip (this is the same buffer
  layout U8g2/Adafruit_GFX use internally for these controllers)
- The firmware `memcpy`s the payload straight into the display buffer,
  so the Brain App must render into this exact layout — no header, no
  metadata, just the 1024 raw bytes.

This is intentionally the simplest correct thing. When you're ready to
optimize to dirty-rectangle updates, that's a protocol change only —
add a small header (e.g. x, y, w, h + partial bytes) and swap the
`sendBuffer()` call in `DisplayDriver::writeFrame` for a partial
`updateDisplayArea()` call. No restructuring needed elsewhere.

## Behavior notes

- **Battery brownout protection**: a full-white frame draws noticeably
  more current on these OLED panels than typical content, and a small
  battery can sag enough under that spike to trip the ESP32's brownout
  detector (USB doesn't show this since it can source far more current).
  Display contrast is dimmed to `DISPLAY_CONTRAST` (60% by default) in
  `Config.h` to cut peak current — tune it lower if you still see resets
  on all-white frames. If brownouts persist even at low contrast, add a
  100–470µF capacitor across the OLED's VCC/GND close to the module —
  that smooths out the current spike itself rather than just reducing
  it.
- **Idle sleep**: after `IDLE_TIMEOUT_MS` (30s default, see `Config.h`)
  with no new frame, the screen powers down and WiFi enters modem-sleep.
  The WebSocket connection is preserved; the next incoming frame wakes
  both instantly.
- **Offline fallback**: if the WebSocket client disconnects, the device
  shows uptime + its IP instead of going blank, refreshed once a second.
- **Reconnect**: if the STA connection itself drops, the device falls
  back to `WIFI_CONNECT` state and retries known networks before
  re-provisioning.
- **Battery reporting** on the offline screen is stubbed out — no
  battery-sense pin was specified in the original pinout. Wire a divider
  to a free ADC pin and set `BATTERY_ADC_PIN` in `OfflineScreen.cpp` to
  enable it.
