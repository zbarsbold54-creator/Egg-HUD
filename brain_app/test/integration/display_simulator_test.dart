// Simulator integration tests: verifies renderer + encoder + transforms
// produce correct frames for the HUD simulator.
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/display/framebuffer/framebuffer.dart';
import 'package:brain_app/display/renderer/display_renderer.dart';
import 'package:brain_app/display/transformations/display_transform.dart';

void main() {
  group('Display Simulator Pipeline', () {
    test('renderer sends only on change', () {
      final renderer = DisplayRenderer();
      final sent = <List<int>>[];
      renderer.setSink((bytes) => sent.add(bytes));

      renderer.canvas.setPixel(0, 0, true);
      renderer.requestFrame();
      expect(sent.length, 1);
      expect(sent.first.length, 1024);

      // No change — no send
      renderer.requestFrame();
      expect(sent.length, 1);

      // Change — send
      renderer.canvas.setPixel(1, 0, true);
      renderer.requestFrame();
      expect(sent.length, 2);

      renderer.dispose();
    });

    test('transform pipeline preserves 1024 bytes', () {
      final renderer = DisplayRenderer();
      renderer.setTransform(const DisplayTransform(flipHorizontal: true, invert: true));
      renderer.canvas.setPixel(0, 0, true);
      final bytes = renderer.getCurrentBytes();
      expect(bytes.length, 1024);
      renderer.dispose();
    });

    test('checkerboard via renderer matches encoder', () {
      final renderer = DisplayRenderer();
      for (int y = 0; y < 64; y++) {
        for (int x = 0; x < 128; x++) {
          renderer.canvas.setPixel(x, y, ((x ~/ 8) + (y ~/ 8)) % 2 == 0);
        }
      }
      final bytes = renderer.getCurrentBytes();
      expect(bytes.length, 1024);
      // (0,0) should be on
      final fb = Framebuffer.fromBytes(bytes);
      expect(fb.getPixel(0, 0), true);
      expect(fb.getPixel(8, 0), false);
      renderer.dispose();
    });
  });
}
