#include "OfflineScreen.h"
#include "DisplayDriver.h"
#include "WiFiManager.h"

OfflineScreen Offline;

// No battery-sense pin was in the original pinout, so this is stubbed.
// Wire a divider to an ADC-capable pin and set BATTERY_ADC_PIN to enable it.
#define BATTERY_ADC_PIN -1

static String formatUptime() {
  uint32_t s = millis() / 1000;
  uint32_t h = s / 3600;
  uint32_t m = (s % 3600) / 60;
  uint32_t sec = s % 60;
  char buf[16];
  snprintf(buf, sizeof(buf), "%02u:%02u:%02u", h, m, sec);
  return String(buf);
}

void OfflineScreen::render() {
  Display.clear();
  Display.setFontSmall();  // portrait (64px wide): 6x10 overflows
  Display.drawText(0, 12, "-- offline --");
  Display.drawText(0, 24, ("up " + formatUptime()).c_str());

  if (Wifi.isConnected()) {
    Display.drawText(0, 36, Wifi.localIP().c_str());
  } else {
    Display.drawText(0, 36, "no wifi");
  }

#if BATTERY_ADC_PIN >= 0
  int raw = analogRead(BATTERY_ADC_PIN);
  // TODO: convert raw ADC reading to voltage/percent once divider is wired.
  Display.drawText(0, 48, ("batt raw:" + String(raw)).c_str());
#else
  Display.drawText(0, 48, "batt: n/a");
#endif
  Display.setFontNormal();

  Display.present();
}
