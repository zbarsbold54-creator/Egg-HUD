/// 128x64 1-bit framebuffer with SSD130x page layout.
///
/// Layout (frozen, must match firmware byte-for-byte):
/// - 8 pages, each 8 rows tall. Page 0 = rows 0-7 (top).
/// - Buffer is page-major, then column: buffer[page * 128 + column]
/// - Within a byte, bit 0 (LSB) = top-most row of that page,
///   bit 7 (MSB) = bottom-most row.
/// - Pixel (x, y): page = y / 8, bitPos = y % 8,
///   buffer[page*128 + x] |= (1 << bitPos) if on.
///
/// Total size: 128 * 64 / 8 = 1024 bytes.
library;

class Framebuffer {
  static const int width = 128;
  static const int height = 64;
  static const int pages = 8;
  static const int byteCount = 1024;

  final List<int> _bytes = List<int>.filled(byteCount, 0);

  Framebuffer();

  /// Create from an existing 1024-byte buffer (copied).
  factory Framebuffer.fromBytes(List<int> bytes) {
    assert(bytes.length == byteCount, 'Framebuffer must be exactly 1024 bytes');
    final fb = Framebuffer();
    fb._bytes.setAll(0, bytes);
    return fb;
  }

  /// Unmodifiable view of the raw 1024 bytes.
  List<int> get bytes => List<int>.unmodifiable(_bytes);

  /// Mutable access for encoder (internal use).
  List<int> get mutableBytes => _bytes;

  void clear() {
    _bytes.fillRange(0, byteCount, 0);
  }

  void fill(bool on) {
    _bytes.fillRange(0, byteCount, on ? 0xFF : 0x00);
  }

  bool getPixel(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return false;
    final page = y ~/ 8;
    final bitPos = y % 8;
    final idx = page * width + x;
    return ((_bytes[idx] >> bitPos) & 1) == 1;
  }

  void setPixel(int x, int y, bool on) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    final page = y ~/ 8;
    final bitPos = y % 8;
    final idx = page * width + x;
    if (on) {
      _bytes[idx] |= (1 << bitPos);
    } else {
      _bytes[idx] &= ~(1 << bitPos);
    }
  }

  void drawRect(int x, int y, int w, int h, bool on) {
    for (int dy = 0; dy < h; dy++) {
      for (int dx = 0; dx < w; dx++) {
        setPixel(x + dx, y + dy, on);
      }
    }
  }

  void drawBorder(bool on) {
    for (int x = 0; x < width; x++) {
      setPixel(x, 0, on);
      setPixel(x, height - 1, on);
    }
    for (int y = 0; y < height; y++) {
      setPixel(0, y, on);
      setPixel(width - 1, y, on);
    }
  }

  void drawLine(int x0, int y0, int x1, int y1, bool on) {
    int dx = (x1 - x0).abs();
    int dy = -(y1 - y0).abs();
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;
    int x = x0, y = y0;
    while (true) {
      setPixel(x, y, on);
      if (x == x1 && y == y1) break;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y += sy;
      }
    }
  }

  void drawCircle(int cx, int cy, int r, bool on, {bool filled = false}) {
    if (filled) {
      for (int y = cy - r; y <= cy + r; y++) {
        for (int x = cx - r; x <= cx + r; x++) {
          final dx = x - cx;
          final dy = y - cy;
          if (dx * dx + dy * dy <= r * r) setPixel(x, y, on);
        }
      }
    } else {
      int x = r, y = 0;
      int err = 0;
      while (x >= y) {
        setPixel(cx + x, cy + y, on);
        setPixel(cx + y, cy + x, on);
        setPixel(cx - y, cy + x, on);
        setPixel(cx - x, cy + y, on);
        setPixel(cx - x, cy - y, on);
        setPixel(cx - y, cy - x, on);
        setPixel(cx + y, cy - x, on);
        setPixel(cx + x, cy - y, on);
        y++;
        if (err <= 0) {
          err += 2 * y + 1;
        }
        if (err > 0) {
          x--;
          err -= 2 * x + 1;
        }
      }
    }
  }

  /// Copy pixels from [src] at offset (dx, dy) onto this buffer.
  void blit(Framebuffer src, int dx, int dy, {bool invert = false}) {
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (src.getPixel(x, y)) {
          setPixel(dx + x, dy + y, !invert);
        }
      }
    }
  }

  /// Compare two framebuffers for equality.
  bool equals(Framebuffer other) {
    for (int i = 0; i < byteCount; i++) {
      if (_bytes[i] != other._bytes[i]) return false;
    }
    return true;
  }

  /// Hash of the buffer for change detection.
  int get hash => Object.hashAll(_bytes);
}
