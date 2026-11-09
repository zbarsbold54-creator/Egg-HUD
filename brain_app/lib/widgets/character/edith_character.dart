/// EDITH animated character widget for the phone UI.
/// Spider-Man holographic HUD: monochrome white, targeting circles,
/// floating eye/orb, scanning lines, orbital animations.
/// Mirrors the 128x64 EDITH orb states.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../display/renderer/display_animation.dart';

class EdithCharacter extends StatelessWidget {
  final EdithState state;
  final double size;
  final double speedMultiplier;

  const EdithCharacter({
    super.key,
    required this.state,
    this.size = 120,
    this.speedMultiplier = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EdithPainter(state: state, speedMultiplier: speedMultiplier),
      ),
    );
  }
}

// Backwards-compat alias
typedef JarvisCharacter = EdithCharacter;

class _EdithPainter extends CustomPainter {
  final EdithState state;
  final double speedMultiplier;
  _EdithPainter({required this.state, required this.speedMultiplier});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.32;
    final now = DateTime.now().millisecondsSinceEpoch;

    final corePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final dimPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Targeting reticle
    canvas.drawCircle(Offset(cx, cy), r, ringPaint);
    // Ticks
    canvas.drawLine(Offset(cx, cy - r - 4), Offset(cx, cy - r + 2), ringPaint);
    canvas.drawLine(Offset(cx, cy + r - 2), Offset(cx, cy + r + 4), ringPaint);
    canvas.drawLine(Offset(cx - r - 4, cy), Offset(cx - r + 2, cy), ringPaint);
    canvas.drawLine(Offset(cx + r - 2, cy), Offset(cx + r + 4, cy), ringPaint);
    canvas.drawCircle(Offset(cx, cy), r * 0.85, dimPaint);

    switch (state) {
      case EdithState.idle:
        // Floating eye: lens + iris
        canvas.drawLine(Offset(cx - r + 4, cy), Offset(cx + r - 4, cy), ringPaint);
        canvas.drawCircle(Offset(cx, cy), r * 0.18, corePaint);
        break;
      case EdithState.listening:
        for (int i = 0; i < 2; i++) {
          final phase = ((now / 800.0) + i * 0.5) % 1.0;
          canvas.drawCircle(Offset(cx, cy), r + 4 + phase * 12, dimPaint);
        }
        // Scan line
        final scanY = cy - r + ((now / 12.0).floor() % (r * 2));
        canvas.drawLine(Offset(cx - r, scanY), Offset(cx + r, scanY), dimPaint);
        canvas.drawCircle(Offset(cx, cy), r * 0.12, corePaint);
        break;
      case EdithState.thinking:
        for (int i = 0; i < 4; i++) {
          final ang = now / 1000.0 + i * math.pi / 2.0;
          final ox = cx + (r - 2) * math.cos(ang);
          final oy = cy + (r - 2) * math.sin(ang);
          canvas.drawCircle(Offset(ox, oy), 2.5, corePaint);
        }
        break;
      case EdithState.processing:
        final scanX = cx - r + ((now / 10.0).floor() % (r * 2));
        canvas.drawLine(Offset(scanX, cy - r), Offset(scanX, cy + r), dimPaint);
        canvas.drawCircle(Offset(cx, cy), r * 0.12, corePaint);
        break;
      case EdithState.speaking:
        final pulse = (math.sin(now / 220.0) * 0.5 + 0.5);
        final eyeH = r * 0.25 + pulse * r * 0.2;
        canvas.drawLine(Offset(cx - r + 4, cy - eyeH), Offset(cx + r - 4, cy - eyeH), ringPaint);
        canvas.drawLine(Offset(cx - r + 4, cy + eyeH), Offset(cx + r - 4, cy + eyeH), ringPaint);
        canvas.drawCircle(Offset(cx, cy), r * 0.15, corePaint);
        break;
      case EdithState.executing:
        final sweep = (now / 2000.0 % 1.0) * 2 * math.pi;
        canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.9), 0, sweep, false, ringPaint);
        break;
      case EdithState.waiting:
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(cx - 10 + i * 10, cy), 2.5, corePaint);
        }
        break;
      case EdithState.success:
        canvas.drawLine(Offset(cx - 8, cy), Offset(cx - 2, cy + 6), ringPaint);
        canvas.drawLine(Offset(cx - 2, cy + 6), Offset(cx + 10, cy - 8), ringPaint);
        break;
      case EdithState.error:
        canvas.drawLine(Offset(cx, cy - 6), Offset(cx, cy + 2), ringPaint);
        canvas.drawCircle(Offset(cx, cy + 6), 1.5, corePaint);
        break;
      case EdithState.offline:
        canvas.drawLine(Offset(cx - r, cy + r), Offset(cx + r, cy - r), ringPaint);
        canvas.drawCircle(Offset(cx, cy), r * 0.1, corePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(_EdithPainter old) => old.state != state;
}
