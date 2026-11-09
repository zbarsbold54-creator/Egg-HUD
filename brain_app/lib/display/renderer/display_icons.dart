/// 1-bit icons and pixel components for the 128x64 display.
library;

import '../framebuffer/framebuffer.dart';

class DisplayIcons {
  static void drawArrowUp(Framebuffer fb, int x, int y, bool on) {
    fb.drawLine(x + 4, y + 8, x + 4, y + 1, on);
    fb.drawLine(x + 4, y + 1, x + 1, y + 4, on);
    fb.drawLine(x + 4, y + 1, x + 7, y + 4, on);
  }

  static void drawArrowDown(Framebuffer fb, int x, int y, bool on) {
    fb.drawLine(x + 4, y, x + 4, y + 7, on);
    fb.drawLine(x + 4, y + 7, x + 1, y + 4, on);
    fb.drawLine(x + 4, y + 7, x + 7, y + 4, on);
  }

  static void drawArrowLeft(Framebuffer fb, int x, int y, bool on) {
    fb.drawLine(x + 8, y + 4, x + 1, y + 4, on);
    fb.drawLine(x + 1, y + 4, x + 4, y + 1, on);
    fb.drawLine(x + 1, y + 4, x + 4, y + 7, on);
  }

  static void drawArrowRight(Framebuffer fb, int x, int y, bool on) {
    fb.drawLine(x, y + 4, x + 7, y + 4, on);
    fb.drawLine(x + 7, y + 4, x + 4, y + 1, on);
    fb.drawLine(x + 7, y + 4, x + 4, y + 7, on);
  }

  static void drawBattery(Framebuffer fb, int x, int y, double level, bool on) {
    // 20x10 battery outline
    fb.drawRect(x, y, 20, 10, false);
    for (int i = 0; i < 20; i++) {
      fb.setPixel(x + i, y, on);
      fb.setPixel(x + i, y + 9, on);
    }
    for (int i = 0; i < 10; i++) {
      fb.setPixel(x, y + i, on);
      fb.setPixel(x + 19, y + i, on);
    }
    // Terminal
    fb.setPixel(x + 20, y + 3, on);
    fb.setPixel(x + 20, y + 4, on);
    fb.setPixel(x + 20, y + 5, on);
    fb.setPixel(x + 20, y + 6, on);
    // Fill
    final fill = (level.clamp(0.0, 1.0) * 16).round();
    for (int i = 0; i < fill; i++) {
      for (int j = 1; j < 9; j++) {
        fb.setPixel(x + 1 + i, y + j, on);
      }
    }
  }

  static void drawProgressBar(Framebuffer fb, int x, int y, int w, int h, double progress, bool on) {
    fb.drawRect(x, y, w, h, false);
    for (int i = 0; i < w; i++) {
      fb.setPixel(x + i, y, on);
      fb.setPixel(x + i, y + h - 1, on);
    }
    for (int i = 0; i < h; i++) {
      fb.setPixel(x, y + i, on);
      fb.setPixel(x + w - 1, y + i, on);
    }
    final fill = (progress.clamp(0.0, 1.0) * (w - 2)).round();
    for (int i = 0; i < fill; i++) {
      for (int j = 1; j < h - 1; j++) {
        fb.setPixel(x + 1 + i, y + j, on);
      }
    }
  }

  static void drawWifi(Framebuffer fb, int x, int y, int strength, bool on) {
    // strength 0..3
    if (strength >= 1) {
      fb.drawLine(x + 1, y + 7, x + 7, y + 7, on);
    }
    if (strength >= 2) {
      fb.drawLine(x + 2, y + 5, x + 6, y + 5, on);
    }
    if (strength >= 3) {
      fb.drawLine(x + 3, y + 3, x + 5, y + 3, on);
    }
    fb.setPixel(x + 4, y + 8, on);
  }

  static void drawBluetooth(Framebuffer fb, int x, int y, bool on) {
    fb.drawLine(x + 4, y, x + 4, y + 8, on);
    fb.drawLine(x + 4, y, x + 7, y + 2, on);
    fb.drawLine(x + 7, y + 2, x + 4, y + 4, on);
    fb.drawLine(x + 4, y + 4, x + 7, y + 6, on);
    fb.drawLine(x + 7, y + 6, x + 4, y + 8, on);
    fb.drawLine(x + 4, y + 2, x + 1, y + 4, on);
    fb.drawLine(x + 1, y + 4, x + 4, y + 6, on);
  }

  static void drawPlay(Framebuffer fb, int x, int y, bool on) {
    fb.drawLine(x, y, x, y + 8, on);
    fb.drawLine(x, y, x + 6, y + 4, on);
    fb.drawLine(x, y + 8, x + 6, y + 4, on);
  }

  static void drawPause(Framebuffer fb, int x, int y, bool on) {
    fb.drawLine(x + 1, y, x + 1, y + 8, on);
    fb.drawLine(x + 2, y, x + 2, y + 8, on);
    fb.drawLine(x + 5, y, x + 5, y + 8, on);
    fb.drawLine(x + 6, y, x + 6, y + 8, on);
  }

  static void drawSpeaker(Framebuffer fb, int x, int y, bool on) {
    fb.drawRect(x, y + 3, 3, 3, on);
    fb.drawLine(x + 3, y + 3, x + 6, y, on);
    fb.drawLine(x + 6, y, x + 6, y + 8, on);
    fb.drawLine(x + 6, y + 8, x + 3, y + 5, on);
    fb.drawLine(x + 3, y + 5, x + 3, y + 3, on);
  }

  static void drawMic(Framebuffer fb, int x, int y, bool on) {
    fb.drawRect(x + 2, y, 4, 5, false);
    for (int i = 0; i < 4; i++) {
      fb.setPixel(x + 2 + i, y, on);
      fb.setPixel(x + 2 + i, y + 4, on);
    }
    for (int i = 0; i < 5; i++) {
      fb.setPixel(x + 2, y + i, on);
      fb.setPixel(x + 5, y + i, on);
    }
    fb.drawLine(x + 4, y + 5, x + 4, y + 8, on);
    fb.drawLine(x + 2, y + 8, x + 6, y + 8, on);
  }

  static void drawWarning(Framebuffer fb, int x, int y, bool on) {
    fb.drawLine(x + 4, y, x + 8, y + 8, on);
    fb.drawLine(x + 8, y + 8, x, y + 8, on);
    fb.drawLine(x, y + 8, x + 4, y, on);
    fb.setPixel(x + 4, y + 3, on);
    fb.setPixel(x + 4, y + 4, on);
    fb.setPixel(x + 4, y + 6, on);
  }

  static void drawCheck(Framebuffer fb, int x, int y, bool on) {
    fb.drawLine(x, y + 4, x + 3, y + 7, on);
    fb.drawLine(x + 3, y + 7, x + 8, y, on);
  }

  static void drawCross(Framebuffer fb, int x, int y, bool on) {
    fb.drawLine(x, y, x + 8, y + 8, on);
    fb.drawLine(x + 8, y, x, y + 8, on);
  }
}
