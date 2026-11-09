#pragma once
#include <Arduino.h>

// Tracks idle time since the last received frame. Sleeps the screen when
// idle past IDLE_TIMEOUT_MS; wakes instantly the moment a new frame arrives.
// WiFi modem-sleep is only used while a client is connected: with no client
// the radio stays awake so a new connection (and mDNS) is never missed.
class PowerManager {
public:
  void begin();
  void onFrameReceived();   // call whenever WSServer reports a new frame
  void loop();              // call every iteration; handles the idle->sleep transition

  bool isScreenAsleep() const { return _asleep; }

private:
  uint32_t _lastActivity = 0;
  bool _asleep = false;
  bool _radioSleeping = false;
};

extern PowerManager Power;
