import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/display/framebuffer/framebuffer.dart';
import 'package:brain_app/display/encoders/display_frame_encoder.dart';
import 'package:brain_app/display/transformations/display_transform.dart';

void main() {
  group('Framebuffer', () {
    test('size is 1024 bytes', () {
      final fb = Framebuffer();
      expect(fb.bytes.length, 1024);
    });

    test('pixel coordinate conversion', () {
      final fb = Framebuffer();
      fb.setPixel(0, 0, true);
      expect(fb.getPixel(0, 0), true);
      fb.setPixel(127, 63, true);
      expect(fb.getPixel(127, 63), true);
      fb.setPixel(0, 0, false);
      expect(fb.getPixel(0, 0), false);
    });

    test('page ordering: (0,0) is byte 0 bit 0', () {
      final fb = Framebuffer();
      fb.setPixel(0, 0, true);
      expect(fb.bytes[0], 0x01);
    });

    test('page ordering: (0,7) is byte 0 bit 7', () {
      final fb = Framebuffer();
      fb.setPixel(0, 7, true);
      expect(fb.bytes[0], 0x80);
    });

    test('page ordering: (0,8) is byte 128 bit 0', () {
      final fb = Framebuffer();
      fb.setPixel(0, 8, true);
      expect(fb.bytes[128], 0x01);
    });

    test('full-black frame', () {
      final fb = Framebuffer();
      fb.fill(true);
      fb.clear();
      expect(fb.bytes.every((b) => b == 0), true);
    });

    test('full-white frame', () {
      final fb = Framebuffer();
      fb.fill(true);
      expect(fb.bytes.every((b) => b == 0xFF), true);
    });
  });

  group('DisplayFrameEncoder', () {
    test('frame length is exactly 1024', () {
      final enc = DisplayFrameEncoder();
      expect(enc.blackFrame().length, 1024);
      expect(enc.whiteFrame().length, 1024);
      expect(enc.checkerboardFrame().length, 1024);
      expect(enc.halfFrame().length, 1024);
    });

    test('checkerboard pattern', () {
      final enc = DisplayFrameEncoder();
      final frame = enc.checkerboardFrame();
      final fb = enc.decode(frame);
      expect(fb.getPixel(0, 0), true);
      expect(fb.getPixel(8, 0), false);
    });

    test('left-half-white/right-half-black', () {
      final enc = DisplayFrameEncoder();
      final fb = enc.decode(enc.halfFrame());
      expect(fb.getPixel(0, 0), true);
      expect(fb.getPixel(127, 0), false);
    });

    test('encode/decode consistency', () {
      final enc = DisplayFrameEncoder();
      final fb = Framebuffer();
      fb.setPixel(10, 20, true);
      fb.setPixel(50, 30, true);
      final bytes = enc.encode(fb);
      final decoded = enc.decode(bytes);
      expect(decoded.getPixel(10, 20), true);
      expect(decoded.getPixel(50, 30), true);
      expect(decoded.equals(fb), true);
    });

    test('invalid length throws', () {
      final enc = DisplayFrameEncoder();
      expect(() => enc.decode(List<int>.filled(100, 0)), throwsArgumentError);
    });
  });

  group('DisplayTransform', () {
    test('identity preserves frame', () {
      final fb = Framebuffer();
      fb.setPixel(5, 5, true);
      final out = DisplayTransform.identity.apply(fb);
      expect(out.getPixel(5, 5), true);
    });

    test('horizontal flip', () {
      final fb = Framebuffer();
      fb.setPixel(0, 0, true);
      final out = const DisplayTransform(flipHorizontal: true).apply(fb);
      expect(out.getPixel(127, 0), true);
    });

    test('vertical flip', () {
      final fb = Framebuffer();
      fb.setPixel(0, 0, true);
      final out = const DisplayTransform(flipVertical: true).apply(fb);
      expect(out.getPixel(0, 63), true);
    });

    test('180 rotation', () {
      final fb = Framebuffer();
      fb.setPixel(0, 0, true);
      final out = const DisplayTransform(rotation: 180).apply(fb);
      expect(out.getPixel(127, 63), true);
    });

    test('inversion', () {
      final fb = Framebuffer();
      fb.setPixel(0, 0, true);
      final out = const DisplayTransform(invert: true).apply(fb);
      expect(out.getPixel(0, 0), false);
      expect(out.getPixel(1, 0), true);
    });
  });
}
