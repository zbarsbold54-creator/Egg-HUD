/*
 * MPU6050Sensor.h
 * -----------------------------------------------------------------------
 * Thin, focused wrapper around Adafruit_MPU6050 that adds:
 *   - deterministic AD0 pin control
 *   - startup gyro bias calibration (device must be still)
 *   - startup accelerometer bias calibration (assumes resting flat-ish,
 *     only corrects offset, not full 6-point calibration)
 *   - exponential low-pass filtering
 *   - a single Sample struct used by the rest of the firmware
 * -----------------------------------------------------------------------
 */

#pragma once

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include "Config.h"

struct MotionSample {
    float ax, ay, az;   // g's, gravity-compensated is NOT applied here
    float gx, gy, gz;   // deg/s, bias-corrected
    float accelMag;     // magnitude of (ax,ay,az) in g's
    float gyroMag;      // magnitude of (gx,gy,gz) in deg/s
    unsigned long tMs;  // millis() timestamp
};

class MPU6050Sensor {
public:
    MPU6050Sensor();

    // Initializes I2C, the AD0 pin, and the MPU6050. Returns false if the
    // sensor could not be found on the bus.
    bool begin();

    // Blocking calibration routine. Device MUST be held still and level.
    // Averages CALIBRATION_SAMPLES readings to compute gyro bias (all axes)
    // and accelerometer bias for X/Y (Z bias assumes resting near +1g).
    void calibrate();

    // Reads one new filtered sample. Safe to call at any rate; internally
    // just does a single I2C transaction.
    MotionSample read();

    bool isCalibrated() const { return calibrated_; }

    // Exposes bias values (useful for diagnostics over Serial).
    void getGyroBias(float &bx, float &by, float &bz) const;
    void getAccelBias(float &bx, float &by) const;

private:
    Adafruit_MPU6050 mpu_;
    bool calibrated_ = false;

    float gyroBiasX_ = 0, gyroBiasY_ = 0, gyroBiasZ_ = 0;
    float accelBiasX_ = 0, accelBiasY_ = 0;

    // Filter state (previous filtered value) for EMA low-pass.
    float fAx_ = 0, fAy_ = 0, fAz_ = 1.0f;
    float fGx_ = 0, fGy_ = 0, fGz_ = 0;
    bool filterInit_ = false;
};
