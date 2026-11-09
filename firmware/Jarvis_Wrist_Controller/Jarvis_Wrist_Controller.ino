/*
 * Jarvis Palm Mouse
 * =========================================================================
 * ESP32 DevKit + MPU6050 -> BLE air mouse. Tilt/twist your wrist to move
 * the cursor, click the button to left-click, long-press the button to
 * toggle cursor tracking on/off (handy for repositioning your hand
 * without dragging the cursor, the same way lifting a physical mouse off
 * the pad works).
 *
 * Unlike the earlier gesture-button design, cursor tracking runs
 * continuously (the button doesn't gate the sensor) -- that's inherent to
 * how an air mouse has to work, so this build draws more power than the
 * old hold-to-activate one. If you want to save battery, use the button's
 * long-press to pause tracking whenever you're not actively using it.
 *
 * Arduino IDE: this file must be named exactly the same as the folder it
 * lives in. The src/ subfolder is picked up automatically alongside it.
 * =========================================================================
 */

#include "src/Config.h"
#include "src/MPU6050Sensor.h"
#include "src/BLEController.h"

// ---------------------------------------------------------------------
// Global objects
// ---------------------------------------------------------------------
MPU6050Sensor  sensor;
BLEController  ble;

// ---------------------------------------------------------------------
// Cursor tracking state
// ---------------------------------------------------------------------
bool cursorEngaged = MOUSE_ENGAGED_AT_BOOT;
unsigned long lastMoveSampleMs = 0;

// Slowly-adapting estimate of "true zero" for each mapped channel, used to
// correct gyro bias drift that creeps in after the one-time startup
// calibration (see MOUSE_STILLNESS_DPS / MOUSE_BIAS_ADAPT_RATE in Config.h).
float biasEstX = 0.0f;
float biasEstY = 0.0f;

// ---------------------------------------------------------------------
// Button debounce + click/long-press detection
// ---------------------------------------------------------------------
bool buttonRawLast = false;
bool buttonStable = false;
unsigned long buttonLastChangeMs = 0;
bool prevButtonStable = false;
unsigned long pressStartMs = 0;

bool readButtonRawPressed() {
#if BUTTON_ACTIVE_LOW
    return digitalRead(PIN_BUTTON) == LOW;
#else
    return digitalRead(PIN_BUTTON) == HIGH;
#endif
}

// Returns the debounced current pressed/released state. Call exactly once
// per loop() iteration.
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

// ---------------------------------------------------------------------
// Live diagnostic streaming (toggle with the "debug" Serial command)
// ---------------------------------------------------------------------
bool diagnosticMode = false;
unsigned long lastDiagPrintMs = 0;

// ---------------------------------------------------------------------
// Serial console
// ---------------------------------------------------------------------
String serialLineBuffer;

void printBanner() {
    Serial.println();
    Serial.println(F("========================================================"));
    Serial.println(F(" Jarvis Palm Mouse - Serial Console"));
    Serial.println(F("========================================================"));
    Serial.println(F(" Commands:"));
    Serial.println(F("   status               Show connection/calibration/tracking status"));
    Serial.println(F("   engage               Turn cursor tracking ON"));
    Serial.println(F("   disengage            Turn cursor tracking OFF (button long-press also toggles this)"));
    Serial.println(F("   debug                Toggle live sensor diagnostic stream"));
    Serial.println(F("   recalibrate          Redo gyro/accel calibration (keep still)"));
    Serial.println(F("   rezero               Instantly flush accumulated drift (keep still)"));
    Serial.println(F("   help                 Show this menu again"));
    Serial.println(F("========================================================"));
    Serial.println(F(" Tilt/twist your wrist to move the cursor. Click the button to"));
    Serial.println(F(" left-click. Long-press the button to pause/resume tracking."));
    Serial.println(F("========================================================"));
}

void handleStatusCommand() {
    Serial.println(F("--- Status ---"));
    Serial.printf("  BLE connected    : %s\n", ble.isConnected() ? "yes" : "no");
    Serial.printf("  Sensor calibrated: %s\n", sensor.isCalibrated() ? "yes" : "no");
    Serial.printf("  Cursor tracking  : %s\n", cursorEngaged ? "engaged" : "paused");
    Serial.printf("  Button state     : %s\n", debouncedButtonPressed() ? "pressed" : "released");
    Serial.printf("  Drift bias (dps) : X=%.2f Y=%.2f\n", biasEstX, biasEstY);

    float gbx, gby, gbz, abx, aby;
    sensor.getGyroBias(gbx, gby, gbz);
    sensor.getAccelBias(abx, aby);
    Serial.printf("  Gyro bias (dps)  : %.2f %.2f %.2f\n", gbx, gby, gbz);
    Serial.printf("  Accel bias (g)   : %.2f %.2f\n", abx, aby);
}

void processSerialCommand(String line) {
    line.trim();
    if (line.length() == 0) return;
    line.toLowerCase();

    if (line == "status") {
        handleStatusCommand();
    } else if (line == "engage") {
        cursorEngaged = true;
        Serial.println(F("Cursor tracking ENGAGED."));
    } else if (line == "disengage") {
        cursorEngaged = false;
        Serial.println(F("Cursor tracking PAUSED."));
    } else if (line == "debug") {
        diagnosticMode = !diagnosticMode;
        Serial.printf("[DEBUG] Live stream %s.\n", diagnosticMode ? "ON" : "OFF");
    } else if (line == "recalibrate") {
        Serial.println(F("Keep the device still and level..."));
        sensor.calibrate();
        Serial.println(F("Recalibration done."));
    } else if (line == "rezero") {
        MotionSample s = sensor.read();
        biasEstX = s.MOUSE_GYRO_CHANNEL_X;
        biasEstY = s.MOUSE_GYRO_CHANNEL_Y;
        Serial.println(F("Drift estimate reset to current reading."));
    } else if (line == "help") {
        printBanner();
    } else {
        Serial.println(F("Unknown command. Type 'help' for the command list."));
    }
}

void pollSerialConsole() {
    while (Serial.available() > 0) {
        char c = Serial.read();
        if (c == '\n' || c == '\r') {
            if (serialLineBuffer.length() > 0) {
                processSerialCommand(serialLineBuffer);
                serialLineBuffer = "";
            }
        } else {
            serialLineBuffer += c;
        }
    }
}

// ---------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------
void setup() {
    Serial.begin(SERIAL_BAUD);
    delay(300);

    pinMode(PIN_BUTTON, INPUT_PULLUP);
    buttonRawLast = readButtonRawPressed();
    buttonStable = buttonRawLast;
    prevButtonStable = buttonStable;

    printBanner();

    Serial.println(F("[INIT] Starting MPU6050..."));
    if (!sensor.begin()) {
        Serial.println(F("[INIT] ERROR: MPU6050 not found! Check wiring (SDA=GPIO21, SCL=GPIO22, AD0=GPIO4)."));
    } else {
        Serial.println(F("[INIT] MPU6050 OK."));
        Serial.println(F("[INIT] Calibrating... keep the device still and level."));
        sensor.calibrate();
    }

    Serial.println(F("[INIT] Starting BLE HID mouse..."));
    ble.begin();

    Serial.printf("[INIT] Ready. Pair \"%s\" from your device's Bluetooth settings.\n", BLE_DEVICE_NAME);
    Serial.printf("[INIT] Cursor tracking starts %s.\n", cursorEngaged ? "ENGAGED" : "PAUSED");
}

// ---------------------------------------------------------------------
// Main loop
// ---------------------------------------------------------------------
void loop() {
    pollSerialConsole();

    bool pressedNow = debouncedButtonPressed();
    bool pressedEdge = pressedNow && !prevButtonStable;
    bool releasedEdge = !pressedNow && prevButtonStable;
    prevButtonStable = pressedNow;

    unsigned long now = millis();

    if (pressedEdge) {
        pressStartMs = now;
    }

    if (releasedEdge) {
        unsigned long heldMs = now - pressStartMs;
        if (heldMs >= MOUSE_LONG_PRESS_MS) {
            cursorEngaged = !cursorEngaged;
            Serial.printf("[MOUSE] Long press -> cursor tracking %s\n", cursorEngaged ? "ENGAGED" : "PAUSED");
        } else {
            ble.leftClick();
#if DEBUG_ENABLED
            Serial.println(F("[MOUSE] Click"));
#endif
        }
    }

    // Cursor tracking runs continuously, independent of button state --
    // the button only clicks / toggles tracking, it never gates the sensor
    // the way the old gesture build's button did.
    if (now - lastMoveSampleMs >= MOUSE_SAMPLE_INTERVAL_MS) {
        float dtSeconds = (now - lastMoveSampleMs) / 1000.0f;
        lastMoveSampleMs = now;

        MotionSample s = sensor.read();

        if (cursorEngaged) {
            float rawX = s.MOUSE_GYRO_CHANNEL_X;
            float rawY = s.MOUSE_GYRO_CHANNEL_Y;

            // Continuous drift correction: only learn from readings that
            // already look nearly still, so real motion is never damped.
            if (fabsf(rawX) < MOUSE_STILLNESS_DPS) biasEstX += (rawX - biasEstX) * MOUSE_BIAS_ADAPT_RATE;
            if (fabsf(rawY) < MOUSE_STILLNESS_DPS) biasEstY += (rawY - biasEstY) * MOUSE_BIAS_ADAPT_RATE;
            rawX -= biasEstX;
            rawY -= biasEstY;

            if (fabsf(rawX) < MOUSE_DEADZONE_DPS) rawX = 0;
            if (fabsf(rawY) < MOUSE_DEADZONE_DPS) rawY = 0;

#if MOUSE_INVERT_X
            rawX = -rawX;
#endif
#if MOUSE_INVERT_Y
            rawY = -rawY;
#endif

            int dx = (int)roundf(rawX * dtSeconds * MOUSE_SENSITIVITY_X);
            int dy = (int)roundf(rawY * dtSeconds * MOUSE_SENSITIVITY_Y);

            dx = constrain(dx, -MOUSE_MAX_STEP_PX, MOUSE_MAX_STEP_PX);
            dy = constrain(dy, -MOUSE_MAX_STEP_PX, MOUSE_MAX_STEP_PX);

            if (dx != 0 || dy != 0) {
                ble.move(dx, dy);
            }
        }

        if (diagnosticMode && (now - lastDiagPrintMs >= 150)) {
            lastDiagPrintMs = now;
            Serial.printf("[DIAG] %s  gx=%6.1f gy=%6.1f gz=%6.1f dps  ax=%.2f ay=%.2f az=%.2f g  bias(X=%.2f,Y=%.2f)  BLE=%s\n",
                          cursorEngaged ? "TRACK" : "PAUSE",
                          s.gx, s.gy, s.gz, s.ax, s.ay, s.az,
                          biasEstX, biasEstY,
                          ble.isConnected() ? "conn" : "----");
        }
    }
}
