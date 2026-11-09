#pragma once

// Broadcasts hud.local so the Brain App can find the device without
// a hardcoded IP. Call begin() once STA is connected.
namespace MdnsAdvertiser {
  bool begin();
}
