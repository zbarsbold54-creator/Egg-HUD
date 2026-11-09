#pragma once
#include <Arduino.h>
#include <U8g2lib.h>
#include "Config.h"

// Thin wrapper around U8g2's full-framebuffer mode.
// The framebuffer is exactly FRAME_BYTES (1024) in the native SSD130x
// page/column layout, so incoming WebSocket bitmap payloads can be
// memcpy'd straight in with zero conversion.
class DisplayDriver {
public:
  void begin();

  // Writes a raw FRAME_BYTES buffer into the display and pushes it out.
  // Returns false if len != FRAME_BYTES (caller should drop the frame).
  bool writeFrame(const uint8_t* data, size_t len);

  void sleep();     // low-power display off (controller stays initialized)
  void wake();      // resume from sleep, redraws last buffer

  // For the offline fallback screen (text-based, not raw bitmap).
  void clear();
  void drawText(int x, int y, const char* text);
  void setFontSmall();  // 4x6 for portrait mode (IP fits in 64px width)
  void setFontNormal(); // 6x10 default
  void present();   // push whatever's currently drawn/cleared to the panel

  uint8_t* rawBuffer();          // direct access, used by writeFrame
  size_t rawBufferSize() const { return FRAME_BYTES; }

private:
  // Physical OLED is mounted vertically (portrait). U8G2_R1 rotates
  // 90 CW so text appears upright. (U8g2 uses R0/R1/R2/R3, not R90.)
  U8G2_SSD1309_128X64_NONAME0_F_4W_HW_SPI _u8g2{U8G2_R1, /* cs=*/ OLED_CS, /* dc=*/ OLED_DC, /* reset=*/ OLED_RST};
  bool _asleep = false;
};

extern DisplayDriver Display;
