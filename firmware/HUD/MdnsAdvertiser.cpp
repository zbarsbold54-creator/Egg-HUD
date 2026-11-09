#include "MdnsAdvertiser.h"
#include "Config.h"
#include <ESPmDNS.h>

bool MdnsAdvertiser::begin() {
  // Deliberately NOT idempotent: after a WiFi drop + rejoin the mDNS
  // responder can stop answering, so every call restarts it cleanly.
  MDNS.end();
  if (!MDNS.begin(MDNS_HOSTNAME)) {
    Serial.println(F("[MDNS] begin failed"));
    return false;
  }
  MDNS.addService("ws", "tcp", WS_PORT);
  MDNS.addService("input", "tcp", INPUT_WS_PORT);
  Serial.println(F("[MDNS] hud.local _ws._tcp:81"));
  return true;
}
