#pragma once
#include <Arduino.h>

// Minimal local screen shown whenever there's no Brain App connection,
// so the HUD isn't just a blank panel. Shows uptime and the device's
// IP so it's still useful for debugging standalone.
class OfflineScreen {
public:
  void render();   // call periodically (e.g. every OFFLINE_REDRAW_MS) while offline
};

extern OfflineScreen Offline;
