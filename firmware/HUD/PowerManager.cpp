#include "PowerManager.h"
#include "Config.h"
#include "DisplayDriver.h"
#include "WSServer.h"
#include "EspNowBridge.h"
#include <WiFi.h>

PowerManager Power;

void PowerManager::begin() {
  _lastActivity = millis();
}

void PowerManager::onFrameReceived() {
  _lastActivity = millis();

  if (_asleep) {
    Display.wake();
    _asleep = false;
  }
  if (_radioSleeping) {
    WiFi.setSleep(false);   // come out of modem-sleep so the next frame lands promptly
    _radioSleeping = false;
  }
}

void PowerManager::loop() {
  if (!_asleep && millis() - _lastActivity > IDLE_TIMEOUT_MS) {
    Display.sleep();
    _asleep = true;
    Serial.println(F("[PWR] idle: screen sleep"));
  }

  // Radio modem-sleep only while a client is connected. In modem-sleep the
  // Egg can miss mDNS queries and be slow/unreliable to accept a NEW
  // connection, which looks like "won't connect" when the glasses sit idle.
  // ESP-NOW controller needs radio awake; only sleep when no controller.
  bool wantRadioSleep = _asleep && WsServer.clientConnected() && !EspNowBridge::controllerConnected();
  if (wantRadioSleep && !_radioSleeping) {
    WiFi.setSleep(true);    // WebSocket connection is preserved
    _radioSleeping = true;
    Serial.println(F("[PWR] radio modem-sleep on"));
  } else if (!wantRadioSleep && _radioSleeping) {
    WiFi.setSleep(false);
    _radioSleeping = false;
    Serial.println(F("[PWR] radio modem-sleep off"));
  }
}
