#include "WiFiManager.h"
#include <WiFi.h>
#include <Preferences.h>

WiFiManager Wifi;
static Preferences prefs;

static const char* disconnectReasonText(uint8_t r) {
  switch (r) {
    case 2:   return "AUTH_EXPIRE";
    case 8:   return "ASSOC_LEAVE";
    case 15:  return "4WAY_HANDSHAKE_TIMEOUT (usually wrong password)";
    case 200: return "BEACON_TIMEOUT (signal lost)";
    case 201: return "NO_AP_FOUND (SSID not in range, or 5 GHz-only)";
    case 202: return "AUTH_FAIL (wrong password?)";
    case 203: return "ASSOC_FAIL";
    case 204: return "HANDSHAKE_TIMEOUT";
    default:  return "other";
  }
}

// Diagnostics only: logs why the STA link dropped or failed. Never logs
// credentials.
static void onWiFiEvent(arduino_event_id_t event, arduino_event_info_t info) {
  if (event == ARDUINO_EVENT_WIFI_STA_DISCONNECTED) {
    uint8_t r = info.wifi_sta_disconnected.reason;
    Serial.print(F("[WIFI] disconnected, reason="));
    Serial.print(r);
    Serial.print(F(" "));
    Serial.println(disconnectReasonText(r));
  } else if (event == ARDUINO_EVENT_WIFI_STA_GOT_IP) {
    Serial.println(F("[WIFI] got IP"));
  }
}

void WiFiManager::begin() {
  WiFi.onEvent(onWiFiEvent);
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);   // active during connect attempts; PowerManager toggles this later
  loadFromNVS();
}

void WiFiManager::loadFromNVS() {
  prefs.begin("wifi", /*readOnly=*/true);
  _count = prefs.getUChar("count", 0);
  if (_count > MAX_KNOWN_NETWORKS) _count = MAX_KNOWN_NETWORKS;

  for (uint8_t i = 0; i < _count; i++) {
    char keySsid[8], keyPass[8];
    snprintf(keySsid, sizeof(keySsid), "ssid%u", i);
    snprintf(keyPass, sizeof(keyPass), "pass%u", i);
    _nets[i].ssid = prefs.getString(keySsid, "");
    _nets[i].pass = prefs.getString(keyPass, "");
  }
  prefs.end();
}

void WiFiManager::saveToNVS() {
  prefs.begin("wifi", /*readOnly=*/false);
  prefs.putUChar("count", _count);
  for (uint8_t i = 0; i < _count; i++) {
    char keySsid[8], keyPass[8];
    snprintf(keySsid, sizeof(keySsid), "ssid%u", i);
    snprintf(keyPass, sizeof(keyPass), "pass%u", i);
    prefs.putString(keySsid, _nets[i].ssid);
    prefs.putString(keyPass, _nets[i].pass);
  }
  prefs.end();
}

bool WiFiManager::addNetwork(const String& ssid, const String& pass) {
  // Overwrite if SSID already known, else append (dropping oldest if full).
  for (uint8_t i = 0; i < _count; i++) {
    if (_nets[i].ssid == ssid) {
      _nets[i].pass = pass;
      saveToNVS();
      return true;
    }
  }

  if (_count < MAX_KNOWN_NETWORKS) {
    _nets[_count].ssid = ssid;
    _nets[_count].pass = pass;
    _count++;
  } else {
    // Shift everything down, drop the oldest, append newest at the end.
    for (uint8_t i = 1; i < MAX_KNOWN_NETWORKS; i++) _nets[i - 1] = _nets[i];
    _nets[MAX_KNOWN_NETWORKS - 1] = { ssid, pass };
  }
  saveToNVS();
  return true;
}

bool WiFiManager::tryJoin(const String& ssid, const String& pass) {
  Serial.print(F("[WIFI] trying: "));
  Serial.println(ssid);
  WiFi.begin(ssid.c_str(), pass.c_str());

  uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < STA_CONNECT_TIMEOUT_MS) {
    delay(200);
  }

  bool ok = WiFi.status() == WL_CONNECTED;
  Serial.print(F("[WIFI] "));
  Serial.print(ssid);
  Serial.print(F(" "));
  Serial.println(ok ? F("connected") : F("failed"));
  if (ok) {
    Serial.print(F("[WIFI] ip="));
    Serial.print(WiFi.localIP());
    Serial.print(F(" rssi="));
    Serial.println(WiFi.RSSI());
  } else {
    // Stop the background auto-reconnect so a failed attempt doesn't keep
    // hopping channels (which also disturbs the setup AP in AP_STA mode).
    WiFi.disconnect(false);
  }
  return ok;
}

bool WiFiManager::connectToBestKnownNetwork(bool tryHiddenFallback) {
  if (_count == 0) return false;

  int found = WiFi.scanNetworks();
  Serial.print(F("[WIFI] scan found "));
  Serial.print(found);
  Serial.println(F(" network(s)"));

  // Try every known network that is visible, strongest first (the scan
  // result is sorted by signal), instead of giving up after the first miss.
  bool sawKnown = false;
  if (found > 0) {
    for (int i = 0; i < found; i++) {
      String seenSsid = WiFi.SSID(i);
      for (uint8_t k = 0; k < _count; k++) {
        if (_nets[k].ssid == seenSsid) {
          sawKnown = true;
          if (tryJoin(_nets[k].ssid, _nets[k].pass)) {
            WiFi.scanDelete();
            return true;
          }
          break;
        }
      }
    }
  }
  WiFi.scanDelete();

  if (!sawKnown) {
    Serial.println(F("[WIFI] no known SSID in scan"));
    if (tryHiddenFallback) {
      // Hidden networks are invisible to scans; try each directly.
      for (uint8_t k = 0; k < _count; k++) {
        if (tryJoin(_nets[k].ssid, _nets[k].pass)) return true;
      }
    }
  }
  return false;
}

bool WiFiManager::isConnected() const {
  return WiFi.status() == WL_CONNECTED;
}

String WiFiManager::localIP() const {
  return WiFi.localIP().toString();
}
