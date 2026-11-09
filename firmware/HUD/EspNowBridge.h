#pragma once
#include <Arduino.h>

// ESP-NOW bridge: receives controller packets, broadcasts beacons,
// forwards button events to InputWSServer. Display WS (port 81) untouched.
namespace EspNowBridge {
  void begin();
  void loop();
  bool controllerConnected();
  uint8_t controllerStatus(); // 0..5
}
