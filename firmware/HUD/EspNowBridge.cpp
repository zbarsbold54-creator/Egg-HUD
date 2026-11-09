#include "EspNowBridge.h"
#include "Config.h"
#include "InputWSServer.h"
#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>

#define PROTOCOL_VERSION 1
#define BEACON_INTERVAL_MS 2000
#define PEER_TIMEOUT_MS 15000

enum MsgType : uint8_t {
  MSG_BEACON = 1, MSG_ANNOUNCE = 2, MSG_ACK = 3,
  MSG_BUTTON_DOWN = 4, MSG_BUTTON_UP = 5, MSG_HEARTBEAT = 6, MSG_STATUS = 7
};

#pragma pack(push, 1)
struct EspNowPacket {
  uint8_t version; uint8_t type; uint8_t controllerId; uint8_t channel;
  uint32_t seq; uint32_t timestampMs; uint32_t durationMs;
  uint8_t buttonState; uint8_t status; uint8_t mac[6];
};
#pragma pack(pop)

static uint8_t peerMac[6] = {0};
static bool peerAdded = false;
static uint32_t lastSeenMs = 0;
static uint32_t lastBeaconMs = 0;
static uint32_t seqCounter = 0;
static bool started = false;

static void sendToPeer(uint8_t type, uint32_t dur = 0, uint8_t btn = 0, uint8_t status = 3) {
  if (!peerAdded) return;
  EspNowPacket p = {};
  p.version = PROTOCOL_VERSION; p.type = type; p.controllerId = 1;
  p.channel = WiFi.channel(); p.seq = seqCounter++; p.timestampMs = millis();
  p.durationMs = dur; p.buttonState = btn; p.status = status;
  uint8_t mac[6]; WiFi.macAddress(mac); memcpy(p.mac, mac, 6);
  esp_now_send(peerMac, (uint8_t*)&p, sizeof(p));
}

static void onRecv(const esp_now_recv_info_t* info, const uint8_t* data, int len) {
  const uint8_t* mac = info->src_addr;
  Serial.print(F("[ESP-NOW] recv len=")); Serial.println(len);
  if (len != sizeof(EspNowPacket)) return;
  EspNowPacket p; memcpy(&p, data, sizeof(p));
  if (p.version != PROTOCOL_VERSION) return;
  memcpy(peerMac, mac, 6);
  lastSeenMs = millis();
  if (!peerAdded) {
    esp_now_peer_info_t info = {};
    memcpy(info.peer_addr, peerMac, 6);
    info.channel = WiFi.channel(); info.encrypt = false;
    if (esp_now_add_peer(&info) == ESP_OK) {
      peerAdded = true;
      Serial.print(F("[ESP-NOW] controller found "));
      for (int i = 0; i < 6; i++) { Serial.printf("%02X", peerMac[i]); if (i < 5) Serial.print(":"); }
      Serial.println();
    }
  }
  if (p.type == MSG_ANNOUNCE) {
    sendToPeer(MSG_ACK);
    Serial.println(F("[ESP-NOW] controller announced, ACK sent"));
  } else if (p.type == MSG_BUTTON_DOWN) {
    InputWs.forwardButtonDown(p.seq, p.timestampMs);
  } else if (p.type == MSG_BUTTON_UP) {
    InputWs.forwardButtonUp(p.seq, p.timestampMs, p.durationMs);
  } else if (p.type == MSG_HEARTBEAT) {
    // liveness only
  }
}

namespace EspNowBridge {
void begin() {
  if (started) return;
  if (esp_now_init() != ESP_OK) { Serial.println(F("[ESP-NOW] init failed")); return; }
  esp_now_register_recv_cb(onRecv);
  uint8_t bcast[6] = {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF};
  esp_now_peer_info_t binfo = {};
  memcpy(binfo.peer_addr, bcast, 6);
  binfo.channel = WiFi.channel();
  binfo.encrypt = false;
  esp_now_add_peer(&binfo);
  started = true;
  Serial.print(F("[ESP-NOW] ready ch="));
  Serial.println(WiFi.channel());
}
void loop() {
  if (!started) return;
  uint32_t now = millis();
  if (now - lastBeaconMs > BEACON_INTERVAL_MS) {
    lastBeaconMs = now;
    EspNowPacket p = {};
    p.version = PROTOCOL_VERSION; p.type = MSG_BEACON; p.controllerId = 0;
    p.channel = WiFi.channel(); p.seq = seqCounter++; p.timestampMs = now;
    uint8_t mac[6]; WiFi.macAddress(mac); memcpy(p.mac, mac, 6);
    uint8_t bcast[6] = {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF};
    esp_err_t e = esp_now_send(bcast, (uint8_t*)&p, sizeof(p));
    static int bcnt = 0;
    if (bcnt++ < 5) { Serial.print(F("[ESP-NOW] beacon ch=")); Serial.print(p.channel); Serial.print(F(" err=")); Serial.println((int)e); }
  }
  if (peerAdded && now - lastSeenMs > PEER_TIMEOUT_MS) {
    esp_now_del_peer(peerMac);
    peerAdded = false;
    Serial.println(F("[ESP-NOW] controller timeout"));
  }
}
bool controllerConnected() { return peerAdded && (millis() - lastSeenMs <= PEER_TIMEOUT_MS); }
uint8_t controllerStatus() {
  if (!started) return 5;
  if (!peerAdded) return 1;
  if (millis() - lastSeenMs > PEER_TIMEOUT_MS) return 4;
  return 3;
}
}
