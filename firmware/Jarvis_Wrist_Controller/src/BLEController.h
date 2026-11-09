/*
 * BLEController.h
 * -----------------------------------------------------------------------
 * Thin wrapper around the BleMouse library (T-vK/ESP32-BLE-Mouse).
 * Presents the ESP32 as a standard BLE HID mouse -- works with
 * Windows/macOS/Linux/Android/iOS without any custom driver, exactly like
 * a Bluetooth mouse.
 * -----------------------------------------------------------------------
 */

#pragma once

#include <Arduino.h>
#include <BleMouse.h>
#include "Config.h"

class BLEController {
public:
    void begin();

    bool isConnected();

    // Relative cursor movement (one HID report). dx/dy/wheel are clamped
    // internally to the signed-byte range a HID mouse report allows
    // (-127..127) -- call this often with small deltas rather than rarely
    // with large ones for smooth motion.
    void move(int dx, int dy, int wheel = 0);

    void leftClick();
    void rightClick();
    void pressLeft();
    void releaseLeft();

private:
    BleMouse bleMouse_{BLE_DEVICE_NAME, BLE_MANUFACTURER, BLE_BATTERY_LEVEL};
};
