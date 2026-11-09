/*
 * Single Bluetooth HID Button
 * =========================================================================
 * ESP32 DevKit + 1 button (GPIO25) -> BLE HID mouse left-click.
 * The phone app (EDITH) interprets timing: short=next, double=select,
 * 2s=exit, Morse dot/dash by duration. Firmware only sends press/release.
 *
 * Wiring:
 *   Button leg 1 -> GPIO25
 *   Button leg 2 -> GND
 *   (Internal pull-up, active-low. No external resistor.)
 *
 * Pairs as "EDITH Button" — standard Bluetooth mouse, OS-level pairing.
 * No MPU6050, no gyro, no Palm Mouse code.
 * Uses ESP32BLECombo (NimBLE, maintained, core 3.x compatible).
 * T-vK BLE Mouse 0.3.1 is incompatible with esp32 core 3.3.11.
 * =========================================================================
 */

#include <ESP32BLECombo.h>

#define PIN_BUTTON 25
#define BUTTON_DEBOUNCE_MS 25
#define SERIAL_BAUD 115200

ESP32BLECombo ble;

bool buttonRawLast = false;
bool buttonStable = false;
unsigned long buttonLastChangeMs = 0;
bool prevStable = false;

bool readButtonRawPressed() {
  return digitalRead(PIN_BUTTON) == LOW;  // active-low
}

bool debouncedButtonPressed() {
  bool raw = readButtonRawPressed();
  if (raw != buttonRawLast) {
    buttonLastChangeMs = millis();
    buttonRawLast = raw;
  }
  if ((millis() - buttonLastChangeMs) > BUTTON_DEBOUNCE_MS) {
    buttonStable = raw;
  }
  return buttonStable;
}

void setup() {
  Serial.begin(SERIAL_BAUD);
  delay(300);

  pinMode(PIN_BUTTON, INPUT_PULLUP);
  buttonRawLast = readButtonRawPressed();
  buttonStable = buttonRawLast;
  prevStable = buttonStable;

  ESP32BLEComboConfig cfg;
  cfg.mode = ESP32BLEComboMode::MOUSE_ONLY;
  cfg.deviceName = "EDITH Button";
  cfg.manufacturer = "EDITH";
  cfg.batteryLevel = 100;
  cfg.appearance = ESP32BLEComboAppearance::AUTO;

  Serial.println(F("EDITH Button - starting BLE HID mouse..."));
  ble.begin(cfg);
  Serial.println(F("Ready. Pair \"EDITH Button\" in Bluetooth settings."));
}

void loop() {
  bool pressedNow = debouncedButtonPressed();
  bool pressedEdge = pressedNow && !prevStable;
  bool releasedEdge = !pressedNow && prevStable;
  prevStable = pressedNow;

  if (pressedEdge) {
    if (ble.isConnected()) {
      ble.mousePress(ESP32BLECombo::MOUSE_LEFT);
    }
    Serial.println(F("[BTN] down"));
  }
  if (releasedEdge) {
    if (ble.isConnected()) {
      ble.mouseRelease(ESP32BLECombo::MOUSE_LEFT);
    }
    Serial.println(F("[BTN] up"));
  }

  delay(5);
}
