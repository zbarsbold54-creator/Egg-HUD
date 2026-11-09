// EDITH Controller — ESP32 DevKit, ESP-NOW button -> HUD Egg
// Button on GPIO27 (active-low, internal pull-up). No BLE, no gyro.
// Discovers HUD via ESP-NOW beacons, sends press/release with seq + duration.

#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>

#define PIN_BUTTON 27
#define BUTTON_DEBOUNCE_MS 25
#define SERIAL_BAUD 115200
#define PROTOCOL_VERSION 1
#define CONTROLLER_ID 1
#define BEACON_INTERVAL_MS 2000
#define HEARTBEAT_INTERVAL_MS 5000
#define PEER_TIMEOUT_MS 15000
#define CHANNEL_DWELL_MS 1000

enum MsgType : uint8_t {
  MSG_BEACON = 1,      // HUD -> broadcast
  MSG_ANNOUNCE = 2,    // controller -> HUD
  MSG_ACK = 3,         // HUD -> controller
  MSG_BUTTON_DOWN = 4,
  MSG_BUTTON_UP = 5,
  MSG_HEARTBEAT = 6,
  MSG_STATUS = 7
};

#pragma pack(push, 1)
struct EspNowPacket {
  uint8_t version;
  uint8_t type;
  uint8_t controllerId;
  uint8_t channel;
  uint32_t seq;
  uint32_t timestampMs;
  uint32_t durationMs;
  uint8_t buttonState; // 0 released, 1 pressed
  uint8_t status;      // 0 disconnected, 1 searching, 2 connecting, 3 connected, 4 reconnecting, 5 error
  uint8_t mac[6];
};
#pragma pack(pop)

static uint8_t hudMac[6] = {0};
static bool peerAdded = false;
static uint32_t seqCounter = 0;
static uint32_t lastBeaconMs = 0;
static uint32_t lastHeartbeatMs = 0;
static uint32_t lastPeerSeenMs = 0;
static uint8_t currentChannel = 0;
static bool connected = false;

static bool buttonRawLast = false;
static bool buttonStable = false;
static uint32_t buttonLastChangeMs = 0;
static bool prevButtonStable = false;
static uint32_t pressStartMs = 0;

static bool readButtonRaw() { return digitalRead(PIN_BUTTON) == LOW; }
static bool debouncedButton() {
  bool raw = readButtonRaw();
  if (raw != buttonRawLast) { buttonLastChangeMs = millis(); buttonRawLast = raw; }
  if (millis() - buttonLastChangeMs > BUTTON_DEBOUNCE_MS) buttonStable = raw;
  return buttonStable;
}

static void sendPacket(uint8_t type, uint32_t durationMs = 0, uint8_t btn = 0, uint8_t status = 3) {
  if (!peerAdded) return;
  EspNowPacket p = {};
  p.version = PROTOCOL_VERSION;
  p.type = type;
  p.controllerId = CONTROLLER_ID;
  p.channel = currentChannel;
  p.seq = seqCounter++;
  p.timestampMs = millis();
  p.durationMs = durationMs;
  p.buttonState = btn;
  p.status = status;
  memcpy(p.mac, WiFi.macAddress().c_str(), 0); // placeholder, filled below
  uint8_t mac[6];
  WiFi.macAddress(mac);
  memcpy(p.mac, mac, 6);
  esp_now_send(hudMac, (uint8_t*)&p, sizeof(p));
}

static void onRecv(const esp_now_recv_info_t* info, const uint8_t* data, int len) {
  const uint8_t* mac = info->src_addr;
  Serial.print(F("[CTRL] recv len=")); Serial.print(len); Serial.print(F(" ch=")); Serial.println(WiFi.channel());
  if (len != sizeof(EspNowPacket)) return;
  EspNowPacket p;
  memcpy(&p, data, sizeof(p));
  if (p.version != PROTOCOL_VERSION) return;
  if (p.type == MSG_BEACON) {
    memcpy(hudMac, mac, 6);
    currentChannel = p.channel;
    lastBeaconMs = millis();
    lastPeerSeenMs = millis();
    if (!peerAdded) {
      esp_now_peer_info_t info = {};
      memcpy(info.peer_addr, hudMac, 6);
      info.channel = currentChannel;
      info.encrypt = false;
      if (esp_now_add_peer(&info) == ESP_OK) {
        peerAdded = true;
        Serial.print(F("[CTRL] HUD found ch="));
        Serial.print(currentChannel);
        Serial.print(F(" mac="));
        for (int i = 0; i < 6; i++) { Serial.printf("%02X", hudMac[i]); if (i < 5) Serial.print(":"); }
        Serial.println();
        sendPacket(MSG_ANNOUNCE);
      }
    }
  } else if (p.type == MSG_ACK) {
    lastPeerSeenMs = millis();
    if (!connected) { connected = true; Serial.println(F("[CTRL] CONNECTED")); }
  } else if (p.type == MSG_STATUS || p.type == MSG_HEARTBEAT) {
    lastPeerSeenMs = millis();
  }
}

static void scanChannels() {
  // ponytail: fixed ch11, no scanning (HUD is on ch11)
  return;
  for (uint8_t ch = 11; ch <= 11; ch++) {
    Serial.print(F("[CTRL] scan ch=")); Serial.println(ch);
    esp_wifi_set_channel(ch, WIFI_SECOND_CHAN_NONE);
    uint32_t start = millis();
    while (millis() - start < CHANNEL_DWELL_MS) {
      if (peerAdded) return;
      delay(10);
    }
  }
}

void setup() {
  Serial.begin(SERIAL_BAUD);
  delay(300);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  buttonRawLast = readButtonRaw();
  buttonStable = buttonRawLast;
  prevButtonStable = buttonStable;

  delay(1000);
  WiFi.mode(WIFI_STA);
  WiFi.setTxPower(WIFI_POWER_7dBm);
  WiFi.disconnect(true);
  esp_wifi_set_channel(11, WIFI_SECOND_CHAN_NONE);
  if (esp_now_init() != ESP_OK) { Serial.println(F("[CTRL] esp_now_init failed")); return; }
  esp_now_register_recv_cb(onRecv);
  Serial.println(F("[CTRL] EDITH controller boot, searching for HUD..."));
}

static int loopCnt = 0;
void loop() {
  if ((loopCnt++ % 200) == 0) { Serial.print(F("[CTRL] loop ")); Serial.println(loopCnt); }
  bool pressed = debouncedButton();
  bool downEdge = pressed && !prevButtonStable;
  bool upEdge = !pressed && prevButtonStable;
  prevButtonStable = pressed;
  uint32_t now = millis();

  if (downEdge) {
    pressStartMs = now;
    if (connected) sendPacket(MSG_BUTTON_DOWN, 0, 1);
    Serial.println(F("[CTRL] button down"));
  }
  if (upEdge) {
    uint32_t dur = now - pressStartMs;
    if (connected) sendPacket(MSG_BUTTON_UP, dur, 0);
    Serial.print(F("[CTRL] button up dur="));
    Serial.println(dur);
  }

  if (!peerAdded || (now - lastPeerSeenMs > PEER_TIMEOUT_MS)) {
    if (connected) { connected = false; Serial.println(F("[CTRL] peer timeout, searching")); }
    if (peerAdded && now - lastPeerSeenMs > PEER_TIMEOUT_MS) {
      esp_now_del_peer(hudMac);
      peerAdded = false;
    }
    scanChannels();
  } else {
    if (now - lastHeartbeatMs > HEARTBEAT_INTERVAL_MS) {
      lastHeartbeatMs = now;
      sendPacket(MSG_HEARTBEAT);
    }
  }
  delay(5);
}
