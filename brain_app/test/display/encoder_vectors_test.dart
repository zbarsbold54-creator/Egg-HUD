import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/display/framebuffer/framebuffer.dart';
import 'package:brain_app/display/encoders/display_frame_encoder.dart';
import 'package:brain_app/display/transformations/display_transform.dart';

void main() {
  test('pixel(0,0) -> buf[0] bit0', () {
    final fb = Framebuffer();
    fb.setPixel(0, 0, true);
    final bytes = DisplayFrameEncoder().encode(fb);
    expect(bytes[0] & 0x01, 0x01);
    expect(bytes.length, 1024);
  });

  test('pixel(127,63) -> buf[1023] bit7', () {
    final fb = Framebuffer();
    fb.setPixel(127, 63, true);
    final bytes = DisplayFrameEncoder().encode(fb);
    expect(bytes[1023] & 0x80, 0x80);
  });

  test('flipVertical mirrors Y', () {
    final fb = Framebuffer();
    fb.setPixel(0, 0, true);
    final flipped = DisplayTransform(flipVertical: true).apply(fb);
    expect(flipped.getPixel(0, 63), true);
    expect(flipped.getPixel(0, 0), false);
  });

  test('flipHorizontal mirrors X', () {
    final fb = Framebuffer();
    fb.setPixel(0, 0, true);
    final flipped = DisplayTransform(flipHorizontal: true).apply(fb);
    expect(flipped.getPixel(127, 0), true);
  });

  test('rotation 180 flips both', () {
    final fb = Framebuffer();
    fb.setPixel(0, 0, true);
    final rot = DisplayTransform(rotation: 180).apply(fb);
    expect(rot.getPixel(127, 63), true);
  });

  test('write shared JSON vectors for Python tool', () {
    final vectors = {
      'pixel_0_0': {'x': 0, 'y': 0, 'byte': 0, 'bit': 0},
      'pixel_127_63': {'x': 127, 'y': 63, 'byte': 1023, 'bit': 7},
      'pixel_0_7': {'x': 0, 'y': 7, 'byte': 0, 'bit': 7},
      'pixel_0_8': {'x': 0, 'y': 8, 'byte': 128, 'bit': 0},
    };
    final f = File('test/display/encoder_vectors.json');
    f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(vectors));
    expect(f.existsSync(), true);
  });
}
