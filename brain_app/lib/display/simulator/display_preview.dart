/// Desktop simulator: shows the actual 128x64 output enlarged with
/// nearest-neighbor scaling. Preserves aspect ratio, shows individual
/// pixels, live animation, and the exact transmitted framebuffer.
library;

import 'package:flutter/material.dart';
import '../framebuffer/framebuffer.dart';

class DisplayPreview extends StatelessWidget {
  final List<int> frameBytes;
  final double scale;
  final bool showGrid;
  final bool showFrameInfo;

  const DisplayPreview({
    super.key,
    required this.frameBytes,
    this.scale = 4.0,
    this.showGrid = false,
    this.showFrameInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    final fb = frameBytes.length == Framebuffer.byteCount
        ? Framebuffer.fromBytes(frameBytes)
        : Framebuffer();
    final w = Framebuffer.width * scale;
    final h = Framebuffer.height * scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey, width: 1),
            color: Colors.black,
          ),
          child: CustomPaint(
            painter: _PixelPainter(fb: fb, scale: scale, showGrid: showGrid),
          ),
        ),
        if (showFrameInfo)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${frameBytes.length} bytes • ${frameBytes.length == 1024 ? "VALID" : "INVALID"}',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
      ],
    );
  }
}

class _PixelPainter extends CustomPainter {
  final Framebuffer fb;
  final double scale;
  final bool showGrid;

  _PixelPainter({required this.fb, required this.scale, required this.showGrid});

  @override
  void paint(Canvas canvas, Size size) {
    final onPaint = Paint()..color = Colors.white;
    final offPaint = Paint()..color = Colors.black;
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    for (int y = 0; y < Framebuffer.height; y++) {
      for (int x = 0; x < Framebuffer.width; x++) {
        final rect = Rect.fromLTWH(x * scale, y * scale, scale, scale);
        canvas.drawRect(rect, fb.getPixel(x, y) ? onPaint : offPaint);
        if (showGrid) {
          canvas.drawRect(rect, gridPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) => old.fb.hash != fb.hash || old.scale != scale;
}
