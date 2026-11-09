/// Deterministic, lightweight animations for the 1-bit display.
/// EDITH identity: Spider-Man holographic HUD — monochrome white,
/// circular targeting, floating eye/orb, scanning lines, orbital motion.
/// All animations are functions of [timeMs] only — no state, no randomness.
/// Suitable for 128x64 monochrome with minimal battery cost.
library;

import 'dart:math' as math;
import '../framebuffer/framebuffer.dart';

enum EdithState {
  idle,
  listening,
  thinking,
  processing,
  speaking,
  executing,
  waiting,
  success,
  error,
  offline,
}

// Backwards-compat alias (internal code may still reference JarvisState)
typedef JarvisState = EdithState;

class DisplayAnimation {
  /// Draw the EDITH orb/eye at (cx, cy) with radius [r] for [state] at [timeMs].
  static void drawEdithOrb(
    Framebuffer fb,
    int cx,
    int cy,
    int r,
    EdithState state,
    int timeMs, {
    double speedMultiplier = 1.0,
  }) {
    final t = timeMs * speedMultiplier;
    switch (state) {
      case EdithState.idle:
        _drawIdle(fb, cx, cy, r, t);
        break;
      case EdithState.listening:
        _drawListening(fb, cx, cy, r, t);
        break;
      case EdithState.thinking:
        _drawThinking(fb, cx, cy, r, t);
        break;
      case EdithState.processing:
        _drawProcessing(fb, cx, cy, r, t);
        break;
      case EdithState.speaking:
        _drawSpeaking(fb, cx, cy, r, t);
        break;
      case EdithState.executing:
        _drawExecuting(fb, cx, cy, r, t);
        break;
      case EdithState.waiting:
        _drawWaiting(fb, cx, cy, r, t);
        break;
      case EdithState.success:
        _drawSuccess(fb, cx, cy, r, t);
        break;
      case EdithState.error:
        _drawError(fb, cx, cy, r, t);
        break;
      case EdithState.offline:
        _drawOffline(fb, cx, cy, r, t);
        break;
    }
  }

  /// Backwards-compat alias.
  static void drawJarvisSphere(
    Framebuffer fb,
    int cx,
    int cy,
    int r,
    EdithState state,
    int timeMs, {
    double speedMultiplier = 1.0,
  }) {
    drawEdithOrb(fb, cx, cy, r, state, timeMs, speedMultiplier: speedMultiplier);
  }

  static void _drawTargetingReticle(Framebuffer fb, int cx, int cy, int r) {
    // Circular targeting-inspired elements: outer ring + 4 ticks
    fb.drawCircle(cx, cy, r, true);
    // Ticks at N/E/S/W
    fb.drawLine(cx, cy - r - 2, cx, cy - r + 1, true);
    fb.drawLine(cx, cy + r - 1, cx, cy + r + 2, true);
    fb.drawLine(cx - r - 2, cy, cx - r + 1, cy, true);
    fb.drawLine(cx + r - 1, cy, cx + r + 2, cy, true);
  }

  static void _drawIdle(Framebuffer fb, int cx, int cy, int r, double t) {
    // Subtle floating eye/orb
    final bob = (math.sin(t / 1000.0) * 1.5).round();
    final cyy = cy + bob;
    _drawTargetingReticle(fb, cx, cyy, r);
    // Central eye: horizontal lens + iris
    fb.drawLine(cx - r + 3, cyy, cx + r - 3, cyy, true);
    final irisR = 3 + (math.sin(t / 1400.0) * 0.5 + 0.5).round();
    fb.drawCircle(cx, cyy, irisR, true, filled: true);
    // Slow orbital dot
    final ang = t / 2000.0;
    final ox = cx + ((r + 4) * math.cos(ang)).round();
    final oy = cyy + ((r + 4) * math.sin(ang)).round();
    fb.setPixel(ox, oy, true);
  }

  static void _drawListening(Framebuffer fb, int cx, int cy, int r, double t) {
    _drawTargetingReticle(fb, cx, cy, r);
    // Expanding scanning rings (dashed)
    for (int i = 0; i < 2; i++) {
      final phase = ((t / 800.0) + i * 0.5) % 1.0;
      final rr = r + 3 + (phase * 6).round();
      if (rr < 28) {
        for (int a = 0; a < 360; a += 8) {
          final rad = a * math.pi / 180.0;
          final x = cx + (rr * math.cos(rad)).round();
          final y = cy + (rr * math.sin(rad)).round();
          fb.setPixel(x, y, true);
        }
      }
    }
    // Scanning line sweep
    final scanY = cy - r + ((t / 12.0).floor() % (r * 2));
    fb.drawLine(cx - r, scanY, cx + r, scanY, true);
    fb.drawCircle(cx, cy, 2, true, filled: true);
  }

  static void _drawThinking(Framebuffer fb, int cx, int cy, int r, double t) {
    _drawTargetingReticle(fb, cx, cy, r);
    // Rotating geometric patterns: 4 diamonds orbiting
    for (int i = 0; i < 4; i++) {
      final ang = t / 1000.0 + i * math.pi / 2.0;
      final ox = cx + ((r - 2) * math.cos(ang)).round();
      final oy = cy + ((r - 2) * math.sin(ang)).round();
      fb.setPixel(ox, oy, true);
      fb.setPixel(ox + 1, oy, true);
      fb.setPixel(ox, oy + 1, true);
    }
    // Inner rotating square
    final ang2 = t / 700.0;
    final s = r - 5;
    for (int i = 0; i < 4; i++) {
      final a1 = ang2 + i * math.pi / 2.0;
      final a2 = ang2 + (i + 1) * math.pi / 2.0;
      final x1 = cx + (s * math.cos(a1)).round();
      final y1 = cy + (s * math.sin(a1)).round();
      final x2 = cx + (s * math.cos(a2)).round();
      final y2 = cy + (s * math.sin(a2)).round();
      fb.drawLine(x1, y1, x2, y2, true);
    }
  }

  static void _drawProcessing(Framebuffer fb, int cx, int cy, int r, double t) {
    _drawTargetingReticle(fb, cx, cy, r);
    // Scanning animation: vertical sweep line
    final scanX = cx - r + ((t / 10.0).floor() % (r * 2));
    fb.drawLine(scanX, cy - r, scanX, cy + r, true);
    // Horizontal scan lines
    for (int y = cy - r + 2; y < cy + r; y += 4) {
      fb.drawLine(cx - r + 1, y, cx + r - 1, y, true);
    }
    fb.drawCircle(cx, cy, 2, true, filled: true);
  }

  static void _drawSpeaking(Framebuffer fb, int cx, int cy, int r, double t) {
    // Synchronized pulsing (eye opens/closes with speech rhythm)
    final pulse = (math.sin(t / 220.0) * 0.5 + 0.5);
    final eyeH = (r * 0.4 + pulse * r * 0.3).round();
    _drawTargetingReticle(fb, cx, cy, r);
    // Eye lens
    fb.drawLine(cx - r + 3, cy - eyeH, cx + r - 3, cy - eyeH, true);
    fb.drawLine(cx - r + 3, cy + eyeH, cx + r - 3, cy + eyeH, true);
    fb.drawCircle(cx, cy, 3, true, filled: true);
    // Orbital pulse rings
    for (int i = 0; i < 2; i++) {
      final phase = ((t / 500.0) + i * 0.5) % 1.0;
      final rr = r + 2 + (phase * 4).round();
      for (int a = -50; a <= 50; a += 10) {
        final rad = a * math.pi / 180.0;
        final x = cx + (rr * math.cos(rad)).round();
        final y = cy + (rr * math.sin(rad)).round();
        fb.setPixel(x, y, true);
        final x2 = cx - (rr * math.cos(rad)).round();
        fb.setPixel(x2, y, true);
      }
    }
  }

  static void _drawExecuting(Framebuffer fb, int cx, int cy, int r, double t) {
    _drawTargetingReticle(fb, cx, cy, r);
    // Progress indicators: arc + segmented bar below
    final progress = ((t / 2000.0) % 1.0);
    for (int a = 0; a < progress * 360; a += 3) {
      final rad = a * math.pi / 180.0;
      final x = cx + ((r - 2) * math.cos(rad)).round();
      final y = cy + ((r - 2) * math.sin(rad)).round();
      fb.setPixel(x, y, true);
    }
    // Segmented progress bar
    final barW = r * 2;
    final fill = (progress * barW).round();
    for (int i = 0; i < fill; i += 2) {
      fb.setPixel(cx - r + i, cy + r + 3, true);
    }
    if ((t / 300).floor() % 2 == 0) {
      fb.drawCircle(cx, cy, 2, true, filled: true);
    }
  }

  static void _drawWaiting(Framebuffer fb, int cx, int cy, int r, double t) {
    _drawTargetingReticle(fb, cx, cy, r);
    // Three dots in targeting style
    for (int i = 0; i < 3; i++) {
      final phase = ((t / 600.0) + i * 0.33) % 1.0;
      final yOff = (math.sin(phase * math.pi) * 2).round();
      fb.drawCircle(cx - 6 + i * 6, cy + yOff, 2, true, filled: true);
    }
  }

  static void _drawSuccess(Framebuffer fb, int cx, int cy, int r, double t) {
    _drawTargetingReticle(fb, cx, cy, r);
    // Brief confirmation: checkmark draws in
    final p = (t % 1200) / 600.0;
    if (p < 1.0) {
      final x0 = cx - 6, y0 = cy;
      final x1 = cx - 2, y1 = cy + 4;
      final x2 = cx + 7, y2 = cy - 5;
      if (p < 0.5) {
        final q = p * 2;
        final x = (x0 + (x1 - x0) * q).round();
        final y = (y0 + (y1 - y0) * q).round();
        fb.drawLine(x0, y0, x, y, true);
      } else {
        fb.drawLine(x0, y0, x1, y1, true);
        final q = (p - 0.5) * 2;
        final x = (x1 + (x2 - x1) * q).round();
        final y = (y1 + (y2 - y1) * q).round();
        fb.drawLine(x1, y1, x, y, true);
      }
    } else {
      fb.drawLine(cx - 6, cy, cx - 2, cy + 4, true);
      fb.drawLine(cx - 2, cy + 4, cx + 7, cy - 5, true);
    }
  }

  static void _drawError(Framebuffer fb, int cx, int cy, int r, double t) {
    // Warning indicator: targeting reticle + exclamation
    _drawTargetingReticle(fb, cx, cy, r);
    if ((t / 400).floor() % 2 == 0) {
      fb.drawLine(cx, cy - 4, cx, cy + 2, true);
      fb.setPixel(cx, cy + 5, true);
    }
  }

  static void _drawOffline(Framebuffer fb, int cx, int cy, int r, double t) {
    // Disconnected: dashed reticle + slash, static
    for (int a = 0; a < 360; a += 12) {
      final rad = a * math.pi / 180.0;
      final x = cx + (r * math.cos(rad)).round();
      final y = cy + (r * math.sin(rad)).round();
      fb.setPixel(x, y, true);
    }
    fb.drawLine(cx - r + 2, cy + r - 2, cx + r - 2, cy - r + 2, true);
    fb.drawCircle(cx, cy, 2, true);
  }

  /// Draw a scrolling marquee text (for teleprompter / long messages).
  static void drawScrollingText(Framebuffer fb, int x, int y, int w, String text, int timeMs, {int speedPxPerSec = 20}) {
    // Full implementation in teleprompter module.
    fb.drawRect(x, y, w, 8, false);
  }
}
