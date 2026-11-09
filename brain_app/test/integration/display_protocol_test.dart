import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/core/config/app_config.dart';
import 'package:brain_app/display/encoders/display_frame_encoder.dart';

void main() {
  test('display protocol unchanged: 1024 bytes, port 81, input port 82 separate', () {
    expect(AppConfig.frameBytes, 1024);
    expect(AppConfig.hudPort, 81);
    expect(AppConfig.hudInputPort, 82);
    expect(AppConfig.frameWidth, 128);
    expect(AppConfig.frameHeight, 64);
    final frame = DisplayFrameEncoder().checkerboardFrame();
    expect(frame.length, 1024);
  });
}
