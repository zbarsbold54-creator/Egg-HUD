#pragma once

// ---------- Display (SSD1309, 4-wire SPI) ----------
#define OLED_MOSI   6
#define OLED_SCK    4
#define OLED_CS     7
#define OLED_DC     21
#define OLED_RST    20

#define DISPLAY_W   128
#define DISPLAY_H   64
#define FRAME_BYTES ((DISPLAY_W * DISPLAY_H) / 8)   // 1024 bytes, page-based layout

// Contrast/brightness, 0-255. Lower = less current draw per lit pixel.
// A full-white frame browned out the ESP32 on USB at 153 (~60%).
// 100 (~39%) is the handoff fallback; add a 100-470uF cap across OLED
// VCC/GND if brownouts persist on battery.
#define DISPLAY_CONTRAST  100

// ---------- WiFi / provisioning ----------
#define MAX_KNOWN_NETWORKS   5
#define PROVISION_AP_PREFIX  "HUD-Setup-"
#define STA_CONNECT_TIMEOUT_MS  8000
#define WIFI_SCAN_RETRY_MS      15000   // how often to retry scanning if provisioning idle

// ---------- mDNS ----------
#define MDNS_HOSTNAME  "hud"   // -> hud.local

// ---------- WebSocket server ----------
#define WS_PORT  81

// Heartbeat: server pings each client so dead connections (app killed,
// phone left the WiFi) are dropped instead of lingering as "connected".
#define WS_HEARTBEAT_PING_MS   15000   // ping interval
#define WS_HEARTBEAT_PONG_MS   3000    // wait for pong
#define WS_HEARTBEAT_MAX_FAILS 2       // missed pongs before disconnect

// ---------- Power management ----------
#define IDLE_TIMEOUT_MS       30000   // screen sleeps after this long with no frame
#define OFFLINE_REDRAW_MS     1000    // fallback screen refresh interval

// ---------- Misc ----------
#define SERIAL_BAUD  115200
