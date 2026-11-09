#pragma once
#include <Arduino.h>

// Temporary AP + HTTP server, used only when no known network is in range.
// The Brain App connects to the AP directly, then POSTs credentials to
// http://192.168.4.1/connect  (form fields: ssid, password).
// On success the device saves the network and reboots into STA mode.
class Provisioning {
public:
  void begin();      // brings up the AP + HTTP server
  void loop();       // must be called repeatedly while provisioning is active
  void end();        // tears down AP + server (called right before restart)

  // True while a phone/PC is joined to the setup AP. Scanning/joining a
  // network moves the radio off the AP's channel and would drop them.
  bool hasClient() const;

private:
  String apSSID() const;
};

extern Provisioning Provision;
