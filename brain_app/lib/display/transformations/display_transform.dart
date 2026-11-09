/// Display transformations applied to the final framebuffer before send.
///
/// Logical canvas is always 128x64. Rotation 90/270 rotates within the
/// canvas (center-cropped) to preserve the 1024-byte wire size — it does
/// NOT change the logical size. The OLED is always 128x64 landscape;
/// rotation is a visual orientation fix for sideways mounts.
///
/// All transforms operate on the 128x64 pixel space consistently.
/// Horizontal and vertical flips are independent. Rotation is 0/90/180/270.
/// Inversion flips every pixel. Threshold simulates brightness by
/// dithering (does NOT control physical OLED electrical brightness —
/// that requires firmware contrast support).
library;

import '../framebuffer/framebuffer.dart';

class DisplayTransform {
  final bool flipHorizontal;
  final bool flipVertical;
  final int rotation; // 0, 90, 180, 270
  final bool invert;
  final double threshold; // 0.0..1.0, 1.0 = no thresholding

  const DisplayTransform({
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.rotation = 0,
    this.invert = false,
    this.threshold = 1.0,
  });

  static const DisplayTransform identity = DisplayTransform();

  DisplayTransform copyWith({
    bool? flipHorizontal,
    bool? flipVertical,
    int? rotation,
    bool? invert,
    double? threshold,
  }) {
    return DisplayTransform(
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      rotation: rotation ?? this.rotation,
      invert: invert ?? this.invert,
      threshold: threshold ?? this.threshold,
    );
  }

  /// Apply the transform pipeline to [src], returning a new framebuffer.
  Framebuffer apply(Framebuffer src) {
    var fb = Framebuffer.fromBytes(src.bytes);

    // Threshold (ordered dithering simulation)
    if (threshold < 1.0) {
      fb = _applyThreshold(fb, threshold);
    }

    // Rotation
    if (rotation != 0) {
      fb = _applyRotation(fb, rotation);
    }

    // Flips
    if (flipHorizontal || flipVertical) {
      fb = _applyFlips(fb, flipHorizontal, flipVertical);
    }

    // Inversion
    if (invert) {
      fb = _applyInvert(fb);
    }

    return fb;
  }

  Framebuffer _applyThreshold(Framebuffer src, double t) {
    final out = Framebuffer();
    // Simple 4x4 Bayer dithering
    const bayer = [
      [0, 8, 2, 10],
      [12, 4, 14, 6],
      [3, 11, 1, 9],
      [15, 7, 13, 5],
    ];
    final cutoff = (1.0 - t) * 16.0;
    for (int y = 0; y < Framebuffer.height; y++) {
      for (int x = 0; x < Framebuffer.width; x++) {
        final on = src.getPixel(x, y);
        if (!on) {
          out.setPixel(x, y, false);
        } else {
          final b = bayer[y % 4][x % 4];
          out.setPixel(x, y, b >= cutoff);
        }
      }
    }
    return out;
  }

  Framebuffer _applyRotation(Framebuffer src, int deg) {
    final out = Framebuffer();
    switch (deg % 360) {
      case 0:
        return Framebuffer.fromBytes(src.bytes);
      case 90:
        // 90 CW: (x,y) -> (H-1-y, x). Output is still 128x64 canvas;
        // we rotate within the canvas (center-cropped) to preserve size.
        for (int y = 0; y < Framebuffer.height; y++) {
          for (int x = 0; x < Framebuffer.width; x++) {
            if (src.getPixel(x, y)) {
              final nx = Framebuffer.height - 1 - y;
              final ny = x;
              if (nx >= 0 && nx < Framebuffer.width && ny >= 0 && ny < Framebuffer.height) {
                out.setPixel(nx, ny, true);
              }
            }
          }
        }
        return out;
      case 180:
        for (int y = 0; y < Framebuffer.height; y++) {
          for (int x = 0; x < Framebuffer.width; x++) {
            if (src.getPixel(x, y)) {
              out.setPixel(Framebuffer.width - 1 - x, Framebuffer.height - 1 - y, true);
            }
          }
        }
        return out;
      case 270:
        for (int y = 0; y < Framebuffer.height; y++) {
          for (int x = 0; x < Framebuffer.width; x++) {
            if (src.getPixel(x, y)) {
              final nx = y;
              final ny = Framebuffer.width - 1 - x;
              if (nx >= 0 && nx < Framebuffer.width && ny >= 0 && ny < Framebuffer.height) {
                out.setPixel(nx, ny, true);
              }
            }
          }
        }
        return out;
      default:
        return Framebuffer.fromBytes(src.bytes);
    }
  }

  Framebuffer _applyFlips(Framebuffer src, bool fh, bool fv) {
    final out = Framebuffer();
    for (int y = 0; y < Framebuffer.height; y++) {
      for (int x = 0; x < Framebuffer.width; x++) {
        if (src.getPixel(x, y)) {
          final nx = fh ? Framebuffer.width - 1 - x : x;
          final ny = fv ? Framebuffer.height - 1 - y : y;
          out.setPixel(nx, ny, true);
        }
      }
    }
    return out;
  }

  Framebuffer _applyInvert(Framebuffer src) {
    final out = Framebuffer();
    for (int y = 0; y < Framebuffer.height; y++) {
      for (int x = 0; x < Framebuffer.width; x++) {
        out.setPixel(x, y, !src.getPixel(x, y));
      }
    }
    return out;
  }
}
