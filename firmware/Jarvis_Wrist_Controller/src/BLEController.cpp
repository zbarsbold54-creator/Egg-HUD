#include "BLEController.h"

static int8_t clampToSignedByte(int v) {
    if (v > 127) return 127;
    if (v < -127) return -127;
    return (int8_t)v;
}

void BLEController::begin() {
    bleMouse_.begin();
}

bool BLEController::isConnected() {
    return bleMouse_.isConnected();
}

void BLEController::move(int dx, int dy, int wheel) {
    if (!bleMouse_.isConnected()) return;
    bleMouse_.move(clampToSignedByte(dx), clampToSignedByte(dy), clampToSignedByte(wheel));
}

void BLEController::leftClick() {
    if (!bleMouse_.isConnected()) return;
    bleMouse_.click(MOUSE_LEFT);
}

void BLEController::rightClick() {
    if (!bleMouse_.isConnected()) return;
    bleMouse_.click(MOUSE_RIGHT);
}

void BLEController::pressLeft() {
    if (!bleMouse_.isConnected()) return;
    bleMouse_.press(MOUSE_LEFT);
}

void BLEController::releaseLeft() {
    if (!bleMouse_.isConnected()) return;
    bleMouse_.release(MOUSE_LEFT);
}
