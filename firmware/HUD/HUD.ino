// HUD firmware — ESP32-C3 + SSD1309
// Remote bitmap monitor. Zero decision-making: connects, receives frames,
// displays them, sleeps aggressively when idle. All "brains" live in the
// Brain App; this device just renders what it's told.

#include "Config.h"
#include "DisplayDriver.h"
#include "WiFiManager.h"
#include "Provisioning.h"
#include "MdnsAdvertiser.h"
#include "WSServer.h"
#include "PowerManager.h"
#include "OfflineScreen.h"
#include "EspNowBridge.h"
#include "InputWSServer.h"

enum class HudState {
  BOOT,
  WIFI_CONNECT,
  PROVISIONING,
  RUNNING
};

static HudState state = HudState::BOOT;
static uint32_t lastKnownFrameMillis = 0;
static uint32_t lastOfflineRedraw = 0;
static uint32_t lastScanRetry = 0;

void setup() {
  Serial.begin(SERIAL_BAUD);
  Serial.println(F("[HUD] boot"));

  Display.begin();
  Display.clear();
  Display.drawText(0, 32, "booting...");
  Display.present();

  Wifi.begin();
  state = HudState::WIFI_CONNECT;
  Serial.println(F("[HUD] state: WIFI_CONNECT"));
}

static void enterProvisioning() {
  Display.clear();
  Display.setFontSmall();  // portrait: split long lines
  Display.drawText(0, 40, "setup mode");
  Display.drawText(0, 52, "see app");
  if (Wifi.hasAnyKnownNetwork()) {
    Display.drawText(0, 72, "wifi failed");
    Display.drawText(0, 84, "check pass");
  }
  Display.setFontNormal();
  Display.present();

  Provision.begin();
  state = HudState::PROVISIONING;
  Serial.println(F("[HUD] state: PROVISIONING"));
}

static void enterRunning() {
  bool mdnsOk = MdnsAdvertiser::begin();   // best-effort; HUD still works via IP if this fails
  Serial.print(F("[HUD] mDNS: "));
  Serial.println(mdnsOk ? F("ok") : F("failed"));
  WsServer.begin();
  InputWs.begin();
  EspNowBridge::begin();
  Power.begin();

  Display.clear();
  Display.setFontSmall();  // portrait (64px wide): 6x10 overflows, 4x6 fits
  Display.drawText(0, 64, Wifi.localIP().c_str());
  Display.setFontNormal();
  Display.present();

  state = HudState::RUNNING;
  Serial.print(F("[HUD] state: RUNNING ip="));
  Serial.println(Wifi.localIP());
}

void loop() {
  switch (state) {

    case HudState::WIFI_CONNECT: {
      // Boot / reconnect path: also try hidden SSIDs directly.
      if (Wifi.hasAnyKnownNetwork() && Wifi.connectToBestKnownNetwork(/*tryHiddenFallback=*/true)) {
        enterRunning();
      } else {
        enterProvisioning();
      }
      break;
    }

    case HudState::PROVISIONING: {
      // Provision.loop() restarts the device itself once credentials
      // are received, so there's nothing else to do here.
      Provision.loop();

      // Periodically re-check in case a known network came into range
      // (e.g. phone hotspot turned on) so we don't force provisioning
      // unnecessarily.
      // Skip the retry while someone is on the setup AP: scanning/joining
      // moves the radio off the AP channel and would kick them mid-setup.
      if (millis() - lastScanRetry > WIFI_SCAN_RETRY_MS) {
        lastScanRetry = millis();
        if (!Provision.hasClient() && Wifi.hasAnyKnownNetwork() && Wifi.connectToBestKnownNetwork()) {
          Provision.end();
          enterRunning();
        }
      }
      break;
    }

    case HudState::RUNNING: {
      WsServer.loop();
      InputWs.loop();
      EspNowBridge::loop();

      // Edge-detect new frames to drive the power manager.
      if (WsServer.lastFrameMillis() != lastKnownFrameMillis) {
        lastKnownFrameMillis = WsServer.lastFrameMillis();
        Power.onFrameReceived();
      }
      Power.loop();

      if (!WsServer.clientConnected()) {
        if (millis() - lastOfflineRedraw > OFFLINE_REDRAW_MS) {
          lastOfflineRedraw = millis();
          if (!Power.isScreenAsleep()) {
            Offline.render();
          }
        }
      }

      if (!Wifi.isConnected()) {
        // Lost the network entirely — drop back to reconnect logic.
        Serial.println(F("[HUD] wifi lost -> WIFI_CONNECT"));
        state = HudState::WIFI_CONNECT;
      }
      break;
    }

    case HudState::BOOT:
    default:
      break;
  }
}
