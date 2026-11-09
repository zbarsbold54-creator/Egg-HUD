# Build Prompt: Brain App (Flutter)

You are building the **Brain App** — the central orchestrator for a wearable
HUD system. It owns all state, talks to two ESP32 peripherals (a HUD "Egg"
and a Controller), runs an AI assistant, and uses the OS's normal Bluetooth
audio stack for earbuds (system default mic/speaker — do not build custom
audio pairing logic).

Platform: **Flutter**, targeting phone, tablet, laptop, and desktop from one
codebase.

If anything below is ambiguous or you're about to guess at a protocol
detail, **ask before implementing** — the HUD Egg's firmware is already
built and fixed; the app must conform to it exactly, not the other way
around.

---

## 1. HUD Egg protocol — READ THIS FIRST, IT IS NOT NEGOTIABLE

The HUD Egg is an ESP32-C3 running fixed firmware. It is a dumb remote
display: it does no decision-making, just renders whatever bitmap it's
sent. The Brain App must match its protocol byte-for-byte. Do not deviate,
add headers, or "improve" the format — if a change seems necessary, stop
and flag it instead of implementing a workaround.

### Discovery
- The Egg advertises itself via mDNS as **`hud.local`**, service type
  `_ws._tcp`, on **port 81**.
- Use a Flutter mDNS package (e.g. `multicast_dns` or `bonsoir`) to resolve
  `hud.local` to an IP. Fall back to a manually-entered IP if mDNS
  resolution fails or is blocked (some Android devices restrict
  multicast on certain networks).

### Connection
- Open a plain **WebSocket client** connection to `ws://<resolved-ip>:81`.
- No handshake payload, no auth, no subprotocol. Standard WS connect.
- The Egg does not ping/keep-alive anything special — normal WebSocket
  ping/pong from your client library is sufficient to detect drops.
- On disconnect, reconnect with backoff (this is the Connectivity
  Manager's job — see §4).

### Frame format — full bitmap, binary WS message
Every screen update is sent as a **single binary WebSocket message,
exactly 1024 bytes, with no header of any kind.**

- Canvas is **128×64 pixels, 1 bit per pixel** (monochrome).
- Byte layout is the **native SSD130x page-addressing format**
  (same layout U8g2 / Adafruit_GFX use internally — do not invent your
  own layout):
  - The screen is divided into **8 pages**, each page = 8 pixel rows tall.
  - Page 0 = rows 0–7 (top), page 7 = rows 56–63 (bottom).
  - Buffer is **page-major, then column**: `buffer[page * 128 + column]`,
    for `page` in 0..7 and `column` in 0..127.
  - Within a byte, **bit 0 (LSB) = the top-most row of that page's 8
    rows**, **bit 7 (MSB) = the bottom-most row**. So for pixel at
    `(x, y)`: `page = y / 8`, `bitPos = y % 8`,
    `buffer[page*128 + x] |= (1 << bitPos)` if the pixel is on.
- Total size must be exactly `128 * 64 / 8 = 1024` bytes. The firmware
  silently drops any frame that isn't exactly 1024 bytes — so a
  size mismatch will look like "nothing happens," not an error. Verify
  buffer length before every send.
- There is currently no partial/dirty-rectangle update support — every
  update resends the full 1024 bytes. (This is a known future protocol
  extension on the firmware side, not something the app should try to
  work around by inventing its own diffing header.)

### Provisioning (first-time WiFi setup for the Egg)
If the Egg has no known WiFi network in range, it opens an **open AP**
named `HUD-Setup-XXXX` (XXXX varies per device) and serves a plain HTTP
server on `192.168.4.1:80`.

To provision it, the app must:
1. Detect/prompt the user to connect their phone/laptop's WiFi to the
   `HUD-Setup-*` AP (on mobile, use platform WiFi APIs —
   `WifiNetworkSpecifier` on Android, `NEHotspotConfiguration` on iOS —
   so the OS doesn't drop the app's own internet route unexpectedly;
   on desktop this is just a normal OS WiFi connect, guide the user
   manually if needed).
2. Send:
   ```
   POST http://192.168.4.1/connect
   Content-Type: application/x-www-form-urlencoded

   ssid=<network-name>&password=<network-password>
   ```
3. The Egg saves the credentials, responds `200 OK`, and reboots into
   station mode on its home network. It remembers up to 5 networks and
   will auto-pick whichever is in range on future boots — provisioning
   is a one-time (or rare) flow, not something needed on every launch.
4. After a few seconds, resume normal discovery (§ Discovery above) —
   the Egg will now be reachable at `hud.local` on the home network.

### What the Egg will never send you
The Egg is receive-only from the app's perspective for frames — it does
not send telemetry, button presses, or status messages over the
WebSocket. Don't build handling for incoming WS messages from the Egg
beyond standard connect/disconnect/error events.

---

## 2. Controller (Jarvis Palm Mouse) — read this before touching Input Router

The Controller is a wrist-worn ESP32 running fixed firmware called
**"Jarvis Palm Mouse."** It is a **standard BLE HID mouse** — not a
keyboard, not a custom GATT device, and it does not send keystrokes,
Morse code, or any app-level messages of any kind.

It sends exactly two things over standard Bluetooth HID:
- **Relative cursor movement** (`dx`/`dy`), derived from wrist gyro tilt,
  sent continuously at ~80Hz while tracking is engaged.
- **Left-click**, from a short button press. (A long-press toggles the
  controller's own tracking pause/resume — this happens entirely on the
  device side; the app just sees movement stop/resume, nothing to
  handle specially.)

### What this means for the app
- **Pairing is OS-level, not app-level.** The user pairs "Jarvis Palm
  Mouse" once via the normal Bluetooth settings on their phone/laptop —
  exactly like pairing any Bluetooth mouse. **Do not build any BLE
  scanning/pairing/GATT code for the Controller.** There is no
  Connectivity Manager work needed for this device at all.
- **The app receives ordinary OS pointer events**, not raw HID reports —
  standard Flutter pointer/mouse APIs (`Listener`, `MouseRegion`,
  `PointerHoverEvent`, `PointerDownEvent`/`PointerUpEvent`), the same
  as if the user were using a mouse or trackpad with the app. This only
  works while the app has focus, same as any pointer device.
- **There is no text-entry or keystroke input path from this device.**
  Any screen or feature that needs input must be operable via
  cursor-move + click only — think "point at a menu item, click to
  select," not typing or chorded key sequences.

### Practical implication for screens/features
- **Chess**: moves are made by pointing at a square and clicking (select
  source square, click again on destination), not by typing algebraic
  notation.
- **Navigation**: menus/lists should be built as clickable/hoverable
  targets, not keyboard-shortcut-driven.
- **Reading Assistant**: unaffected — it doesn't need button-side text
  entry (OCR provides the text; TTS reads it; no typing required).
- If a future feature genuinely needs more expressive input than
  cursor+click, that requires new controller hardware/firmware — don't
  try to simulate keystrokes out of mouse motion inside the app.

---

## 3. Render Engine

Maintain an internal **128×64 canvas abstraction** that every screen
draws into. On each update:
1. Screen logic draws into the canvas (whatever drawing API you choose
   internally — Flutter `Canvas`/`Picture`, or a custom pixel buffer).
2. Rasterize/threshold the canvas down to 1-bit monochrome.
3. Serialize to the exact 1024-byte format in §1.
4. Send as a binary WS frame to the Egg.

Only send a frame when the canvas actually changed — don't spam
identical frames (the Egg's power manager sleeps after 30s of no new
frames, and needless frames just burn battery on both ends for no
visible change).

### Screens (each is a "view" the Render Engine can push)
- Home/status
- Now Playing (song + volume)
- Chess board
- Reading (current line/word highlight)
- AI listening/response indicator
- Notification
- Settings/pairing

Each screen should be its own module that knows how to draw itself onto
the shared canvas — don't hardcode screen-specific pixel logic into the
Render Engine itself.

---

## 4. Module breakdown

| Module | Job |
|---|---|
| **Connectivity Manager** | Owns the WebSocket connection to the HUD Egg (per §1) — reconnect/backoff, discovery, provisioning handoff. **No Controller code here** — that's OS-level pairing, not app-managed (see §2). |
| **Render Engine** | Per §3. |
| **Input Router** | Consumes standard OS pointer/click events (from the paired Controller, or a trackpad/mouse/touch on desktop) and routes them based on the currently active screen — cursor-move + click only, per §2. No keystroke or text-entry modes. |
| **AI Assistant Core** | Speech-to-text → tool-calling LLM (Claude/OpenAI) → executes selected tool → text-to-speech reply. Uses the OS's default Bluetooth audio I/O — no custom audio stack. |
| **Feature/Tool Modules** | Plug into the AI Core as callable tools and into the Render Engine as screens: Media Control (Spotify), Chess (point+click moves), Reading Assistant (text/OCR + TTS + HUD highlight), Notifications. |
| **Settings/State Store** | Paired device IDs, API keys, preferences — persisted locally (e.g. `shared_preferences` / `hive` / platform secure storage for keys). |
| **Background Service** | Keeps the HUD WebSocket link alive while backgrounded. (Controller/Bluetooth-audio background behavior is handled by the OS's own Bluetooth stack, not this app.) Budget real dev time here — Android/iOS/desktop background execution limits are genuinely different per platform; don't assume one implementation covers all targets. |

---

## 5. Build order (suggested)

1. Connectivity Manager's Egg half (WS connect, mDNS discovery, send a
   static test frame — e.g. all-white or a checkerboard — to confirm
   the byte layout is correct against real hardware before building
   anything else).
2. Provisioning flow.
3. Render Engine + Home/status screen (simplest screen, proves the
   canvas→bitmap pipeline end to end).
4. Remaining screens.
5. Input Router (pair the Controller at the OS level and confirm plain
   pointer/click events arrive in the app before building screen-specific
   interaction logic on top).
6. AI Assistant Core + tool modules.
7. Background Service last — it's a cross-cutting concern that's easier
   to retrofit once the core pipeline is proven than to get right
   speculatively up front.
