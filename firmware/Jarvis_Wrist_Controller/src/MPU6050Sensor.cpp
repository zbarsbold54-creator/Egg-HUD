#include "MPU6050Sensor.h"

MPU6050Sensor::MPU6050Sensor() {}

bool MPU6050Sensor::begin() {
    // AD0 is firmware-controlled so the I2C address is deterministic
    // regardless of how the breakout board floats that pin.
    pinMode(PIN_MPU_AD0, OUTPUT);
    digitalWrite(PIN_MPU_AD0, MPU_AD0_LEVEL);
    delay(10); // let the address line settle before the sensor is probed

    Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
    Wire.setClock(I2C_CLOCK_HZ);

    if (!mpu_.begin(MPU_I2C_ADDR, &Wire)) {
        return false;
    }

    mpu_.setAccelerometerRange(MPU6050_RANGE_4_G);
    mpu_.setGyroRange(MPU6050_RANGE_500_DEG);
    mpu_.setFilterBandwidth(MPU6050_BAND_44_HZ);

    return true;
}

void MPU6050Sensor::calibrate() {
#if DEBUG_ENABLED
    Serial.println(F("[MPU] Calibrating... keep the device still and level."));
#endif
    double sumGx = 0, sumGy = 0, sumGz = 0;
    double sumAx = 0, sumAy = 0;

    sensors_event_t a, g, temp;

    for (int i = 0; i < CALIBRATION_SAMPLES; i++) {
        mpu_.getEvent(&a, &g, &temp);

        // Convert gyro rad/s -> deg/s
        sumGx += g.gyro.x * RAD_TO_DEG;
        sumGy += g.gyro.y * RAD_TO_DEG;
        sumGz += g.gyro.z * RAD_TO_DEG;

        // Convert accel m/s^2 -> g
        sumAx += a.acceleration.x / 9.80665;
        sumAy += a.acceleration.y / 9.80665;

        delay(CALIBRATION_SAMPLE_DELAY_MS);
    }

    gyroBiasX_ = sumGx / CALIBRATION_SAMPLES;
    gyroBiasY_ = sumGy / CALIBRATION_SAMPLES;
    gyroBiasZ_ = sumGz / CALIBRATION_SAMPLES;

    // Only X/Y accel bias is zeroed; Z is left alone since its "true" bias
    // depends on unknown mounting orientation relative to gravity and we
    // don't want to accidentally cancel gravity itself.
    accelBiasX_ = sumAx / CALIBRATION_SAMPLES;
    accelBiasY_ = sumAy / CALIBRATION_SAMPLES;

    filterInit_ = false;
    calibrated_ = true;

#if DEBUG_ENABLED
    Serial.printf("[MPU] Gyro bias  (dps): %.3f %.3f %.3f\n", gyroBiasX_, gyroBiasY_, gyroBiasZ_);
    Serial.printf("[MPU] Accel bias (g)  : %.3f %.3f\n", accelBiasX_, accelBiasY_);
#endif
}

void MPU6050Sensor::getGyroBias(float &bx, float &by, float &bz) const {
    bx = gyroBiasX_; by = gyroBiasY_; bz = gyroBiasZ_;
}

void MPU6050Sensor::getAccelBias(float &bx, float &by) const {
    bx = accelBiasX_; by = accelBiasY_;
}

MotionSample MPU6050Sensor::read() {
    sensors_event_t a, g, temp;
    mpu_.getEvent(&a, &g, &temp);

    float ax = (a.acceleration.x / 9.80665f) - accelBiasX_;
    float ay = (a.acceleration.y / 9.80665f) - accelBiasY_;
    float az = (a.acceleration.z / 9.80665f);

    float gx = (g.gyro.x * RAD_TO_DEG) - gyroBiasX_;
    float gy = (g.gyro.y * RAD_TO_DEG) - gyroBiasY_;
    float gz = (g.gyro.z * RAD_TO_DEG) - gyroBiasZ_;

    if (!filterInit_) {
        fAx_ = ax; fAy_ = ay; fAz_ = az;
        fGx_ = gx; fGy_ = gy; fGz_ = gz;
        filterInit_ = true;
    } else {
        fAx_ = LPF_ALPHA_ACCEL * ax + (1.0f - LPF_ALPHA_ACCEL) * fAx_;
        fAy_ = LPF_ALPHA_ACCEL * ay + (1.0f - LPF_ALPHA_ACCEL) * fAy_;
        fAz_ = LPF_ALPHA_ACCEL * az + (1.0f - LPF_ALPHA_ACCEL) * fAz_;
        fGx_ = LPF_ALPHA_GYRO  * gx + (1.0f - LPF_ALPHA_GYRO)  * fGx_;
        fGy_ = LPF_ALPHA_GYRO  * gy + (1.0f - LPF_ALPHA_GYRO)  * fGy_;
        fGz_ = LPF_ALPHA_GYRO  * gz + (1.0f - LPF_ALPHA_GYRO)  * fGz_;
    }

    MotionSample s;
    s.ax = fAx_; s.ay = fAy_; s.az = fAz_;
    s.gx = fGx_; s.gy = fGy_; s.gz = fGz_;
    s.accelMag = sqrtf(s.ax * s.ax + s.ay * s.ay + s.az * s.az);
    s.gyroMag  = sqrtf(s.gx * s.gx + s.gy * s.gy + s.gz * s.gz);
    s.tMs = millis();
    return s;
}
