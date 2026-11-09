#include "DisplayDriver.h"
#include <SPI.h>

DisplayDriver Display;

void DisplayDriver::begin() {
  // Remap hardware SPI to our custom pins (ESP32-C3 GPIO matrix allows this).
  // MISO unused for a write-only display, so pass -1.
  SPI.begin(OLED_SCK, /*miso=*/-1, OLED_MOSI, OLED_CS);

  _u8g2.begin();
  _u8g2.setPowerSave(0);
  _u8g2.setContrast(DISPLAY_CONTRAST);
  _u8g2.setFont(u8g2_font_6x10_tf);
  _u8g2.clearBuffer();
  _u8g2.sendBuffer();
}

bool DisplayDriver::writeFrame(const uint8_t* data, size_t len) {
  if (len != FRAME_BYTES) return false;

  uint8_t* buf = _u8g2.getBufferPtr();
  memcpy(buf, data, FRAME_BYTES);
  _u8g2.sendBuffer();   // full-frame push; swap for a partial updateDisplayArea() call later
                        // when the protocol moves to dirty-rectangle updates
  return true;
}

void DisplayDriver::sleep() {
  if (_asleep) return;
  _u8g2.setPowerSave(1);
  _asleep = true;
}

void DisplayDriver::wake() {
  if (!_asleep) return;
  _u8g2.setPowerSave(0);
  _asleep = false;
}

void DisplayDriver::clear() {
  _u8g2.clearBuffer();
}

void DisplayDriver::drawText(int x, int y, const char* text) {
  _u8g2.drawStr(x, y, text);
}

void DisplayDriver::setFontSmall() {
  _u8g2.setFont(u8g2_font_4x6_tf);
}

void DisplayDriver::setFontNormal() {
  _u8g2.setFont(u8g2_font_6x10_tf);
}

void DisplayDriver::present() {
  _u8g2.sendBuffer();
}

uint8_t* DisplayDriver::rawBuffer() {
  return _u8g2.getBufferPtr();
}
