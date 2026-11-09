/*
 * Config.h
 * -----------------------------------------------------------------------
 * Central configuration for the Jarvis Palm Mouse (ESP32 DevKit build).
 * Change pin numbers, tuning, and orientation here.
 * -----------------------------------------------------------------------
 */

#pragma once

// =========================================================================
// BOARD / WIRING  (standard ESP32 DevKitC / WROOM-32 dev board)
// =========================================================================
//   MPU6050 VCC  -> 3.3V
//   MPU6050 GND  -> GND
//   MPU6050 SDA  -> GPIO21   (ESP32 hardware-default I2C SDA)
//   MPU6050 SCL  -> GPIO22   (ESP32 hardware-default I2C SCL)
//   MPU6050 AD0  -> GPIO4    (driven by firmware, LOW = I2C addr 0x68)
//   MPU6050 INT  -> not connected
//   MPU6050 XDA  -> not connected
//   MPU6050 XCL  -> not connected
//
//   Push button  -> one leg to GPIO27, other leg to GND.
//                   Internal pull-up is used -- no external resistor needed.
//
// Pins deliberately avoided: GPIO0/2/5/12/15 (boot-strapping pins),
// GPIO6-11 (wired to internal SPI flash, unusable), GPIO34/35/36/39
// (input-only, no internal pull-up -- awkward for a plain pull-up button).
// Backup pin choices if you need more I/O later: 13, 14, 25, 26, 32, 33.

#define PIN_I2C_SDA      21
#define PIN_I2C_SCL      22
#define PIN_MPU_AD0      4

// Drive AD0 LOW -> MPU6050 I2C address 0x68. If your board wiring instead
// needs AD0 HIGH (address 0x69), flip this to HIGH and MPU_I2C_ADDR below.
#define MPU_AD0_LEVEL    LOW
#define MPU_I2C_ADDR     0x68

#define I2C_CLOCK_HZ     400000UL   // 400kHz fast-mode I2C

// --- Push button (click / long-press) -------------------------------------
#define PIN_BUTTON               27
#define BUTTON_ACTIVE_LOW        1     // button pulls the pin to GND when pressed
#define BUTTON_DEBOUNCE_MS       25

// =========================================================================
// SERIAL / DEBUG
// =========================================================================
#define SERIAL_BAUD      115200
#define DEBUG_ENABLED    1          // set to 0 to silence non-essential logs

// =========================================================================
// BLE HID IDENTITY
// =========================================================================
#define BLE_DEVICE_NAME      "Jarvis Palm Mouse"
#define BLE_MANUFACTURER     "JarvisWear"
#define BLE_BATTERY_LEVEL    100

// =========================================================================
// CALIBRATION
// =========================================================================
// Device MUST be held still and roughly level while this runs (at boot,
// and again any time you send "recalibrate" over Serial). This is what
// keeps the cursor from slowly drifting on its own when your wrist is
// actually still -- the MPU6050's gyro has a small constant bias per axis
// that has to be measured and subtracted.
#define CALIBRATION_SAMPLES          400
#define CALIBRATION_SAMPLE_DELAY_MS  3

// =========================================================================
// FILTERING
// =========================================================================
// Exponential moving average factor for low-pass filtering raw sensor
// values (0..1, higher = less smoothing / more responsive, lower = smoother
// but laggier). MPU6050Sensor applies this internally to every reading.
#define LPF_ALPHA_ACCEL   0.35f
#define LPF_ALPHA_GYRO    0.35f

// =========================================================================
// MOUSE MOTION
// -------------------------------------------------------------------------
// Cursor tracking runs continuously (independent of the button) at this
// rate. The gyro's angular velocity (deg/s) on two axes is turned directly
// into a relative cursor delta each tick: dx/dy = angularVelocity * dt *
// sensitivity. Unlike a physical mouse there's no surface to "run out of",
// so this is closer to how a Wii-style air mouse or a laser pointer works.
// =========================================================================
#define MOUSE_SAMPLE_INTERVAL_MS     12     // ~80Hz cursor update rate

// --- Orientation: THE ONLY PLACE you should need to fix "wrong direction" ---
// Which raw gyro channel drives which cursor axis, and which way is
// "positive". If tilting/twisting your wrist moves the cursor the wrong
// way or the wrong axis, change these four lines -- nothing else in the
// code needs to change, and you never have to re-flash-and-guess against a
// hardcoded heuristic like the old gesture build did.
//
//   MOUSE_GYRO_CHANNEL_X / _Y : which MotionSample field (gx, gy, or gz)
//                               feeds horizontal / vertical cursor motion.
//
// A wrist has three independent rotations, and only two map to a 2D
// cursor -- the third (whichever one isn't picked) simply won't move the
// cursor at all, which is what you want for "twisting the forearm
// shouldn't move the mouse":
//   YAW   (panning your hand left/right, like shaking your head "no")
//   PITCH (tilting your hand up/down, like nodding)
//   ROLL  (twisting your forearm inward/outward, like turning a doorknob)
//
// Defaults below assume a board mounted flat on top of the wrist with its
// long edge along the forearm: yaw -> gz, pitch -> gy, roll -> gx (roll is
// intentionally left unmapped). If cursor movement tracks the wrong one of
// these three motions, that's not a bug to hunt down in code -- it just
// means your specific mount wires roll/pitch/yaw to a different gx/gy/gz
// than this default guess. See README section 7 for the "debug" command
// procedure to nail down exactly which channel is which on your mount.
//   MOUSE_INVERT_X / _Y       : flip direction on that axis (1 = inverted).
#define MOUSE_GYRO_CHANNEL_X   gz
#define MOUSE_GYRO_CHANNEL_Y   gy
#define MOUSE_INVERT_X          0
#define MOUSE_INVERT_Y          0

// Pixels of cursor movement per (deg/s * second) of rotation on each axis.
// Bigger = faster cursor for the same physical motion. Tune X/Y separately
// if one axis feels faster than the other.
#define MOUSE_SENSITIVITY_X    9.0f
#define MOUSE_SENSITIVITY_Y    9.0f

// Below this angular velocity (deg/s), motion is treated as hand tremor /
// sensor noise and ignored entirely, so the cursor sits dead still when
// your wrist is genuinely still. Raise this if you see idle jitter, lower
// it if small deliberate motions aren't registering.
#define MOUSE_DEADZONE_DPS     2.0f

// --- Continuous drift correction ------------------------------------------
// The one-time startup calibration removes gyro bias as measured at that
// moment, but the true bias drifts slowly afterwards (mainly with
// temperature), which is what shows up as the cursor slowly creeping even
// though the device is sitting still. To fix this without another manual
// calibration step: whenever a channel's reading is already small (below
// MOUSE_STILLNESS_DPS), main.ino treats that as evidence of where "true
// zero" currently is for that channel and slowly nudges a running bias
// estimate toward it. Genuine deliberate motion stays well above this
// threshold, so it's never fed into the estimate and never gets damped.
//
//   MOUSE_STILLNESS_DPS   : reading must be under this to count as "still"
//                           enough to learn from. Keep above
//                           MOUSE_DEADZONE_DPS.
//   MOUSE_BIAS_ADAPT_RATE : how fast the estimate chases a still reading,
//                           0..1 per tick. Bigger = corrects drift faster
//                           but can also mean a slow deliberate motion gets
//                           partially damped; smaller = slower to correct
//                           drift but never touches real motion.
#define MOUSE_STILLNESS_DPS      4.0f
#define MOUSE_BIAS_ADAPT_RATE    0.01f

// Optional soft cap on how far the cursor can move in a single tick
// (pixels), independent of the HID report's hard -127..127 limit -- keeps
// a sudden fast motion from making the cursor "teleport".
#define MOUSE_MAX_STEP_PX      40

// =========================================================================
// BUTTON BEHAVIOR
// -------------------------------------------------------------------------
// A press shorter than this on release = a click. A press held longer than
// this = a long-press, which toggles cursor tracking on/off (like lifting
// a physical mouse off the pad so you can reposition your hand without
// dragging the cursor across the screen). Tracking's on/off state persists
// until the next long-press; a click always works regardless of that state.
// =========================================================================
#define MOUSE_LONG_PRESS_MS       450
#define MOUSE_ENGAGED_AT_BOOT     1     // 1 = cursor tracking starts ON
