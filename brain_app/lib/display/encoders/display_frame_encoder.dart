/// Encodes a [Framebuffer] to the frozen 1024-byte wire format.
///
/// The wire format is the native SSD130x page-addressing layout:
/// buffer[page * 128 + column], bit (y % 8), LSB = top row of page.
/// No header, no metadata. Exactly 1024 bytes or the firmware drops it.
library;

import '../framebuffer/framebuffer.dart';

class DisplayFrameEncoder {
  /// Encode [fb] to 1024 bytes. Returns a new list (defensive copy).
  List<int> encode(Framebuffer fb) {
    assert(fb.bytes.length == Framebuffer.byteCount);
    return List<int>.from(fb.bytes);
  }

  /// Decode 1024 bytes back to a [Framebuffer]. Throws if length != 1024.
  Framebuffer decode(List<int> bytes) {
    if (bytes.length != Framebuffer.byteCount) {
      throw ArgumentError('Frame must be exactly 1024 bytes, got ${bytes.length}');
    }
    return Framebuffer.fromBytes(bytes);
  }

  /// Verify a frame is exactly 1024 bytes (pre-send check).
  bool isValidFrame(List<int> bytes) => bytes.length == Framebuffer.byteCount;

  /// Generate a full-black frame (all pixels off).
  List<int> blackFrame() => List<int>.filled(Framebuffer.byteCount, 0x00);

  /// Generate a full-white frame (all pixels on).
  List<int> whiteFrame() => List<int>.filled(Framebuffer.byteCount, 0xFF);

  /// Generate a checkerboard frame (8x8 squares).
  List<int> checkerboardFrame() {
    final fb = Framebuffer();
    for (int y = 0; y < Framebuffer.height; y++) {
      for (int x = 0; x < Framebuffer.width; x++) {
        final on = ((x ~/ 8) + (y ~/ 8)) % 2 == 0;
        fb.setPixel(x, y, on);
      }
    }
    return encode(fb);
  }

  /// Generate left-half-white / right-half-black frame.
  List<int> halfFrame() {
    final fb = Framebuffer();
    for (int y = 0; y < Framebuffer.height; y++) {
      for (int x = 0; x < Framebuffer.width; x++) {
        fb.setPixel(x, y, x < Framebuffer.width ~/ 2);
      }
    }
    return encode(fb);
  }
}
