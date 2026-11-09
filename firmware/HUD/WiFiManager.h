#pragma once
#include <Arduino.h>
#include "Config.h"

// STA-only WiFi manager. Stores up to MAX_KNOWN_NETWORKS SSID/password
// pairs in NVS (Preferences) and auto-connects to whichever known
// network is in range. Never brings up an AP itself — that's Provisioning's job.
class WiFiManager {
public:
  void begin();                                   // loads stored networks from NVS
  // Scans and joins a known SSID that is in range. With tryHiddenFallback,
  // also makes one direct join attempt per known network when none was
  // seen in the scan (hidden SSIDs never show up in scans). Only use the
  // fallback at boot: each attempt blocks for up to STA_CONNECT_TIMEOUT_MS.
  bool connectToBestKnownNetwork(bool tryHiddenFallback = false);
  bool addNetwork(const String& ssid, const String& pass);  // saves + persists
  bool hasAnyKnownNetwork() const { return _count > 0; }

  bool isConnected() const;
  String localIP() const;

private:
  struct Net { String ssid; String pass; };
  Net _nets[MAX_KNOWN_NETWORKS];
  uint8_t _count = 0;

  void loadFromNVS();
  void saveToNVS();
  bool tryJoin(const String& ssid, const String& pass);
};

extern WiFiManager Wifi;
