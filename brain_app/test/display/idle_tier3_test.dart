import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/display/renderer/display_renderer.dart';
import 'package:brain_app/display/renderer/always_on_screen.dart';

void main() {
  test('keep-alive and forceFrame blocked while sleeping', () async {
    final renderer = DisplayRenderer();
    int sends = 0;
    renderer.setSink((_) => sends++);
    renderer.setKeepAlive(enabled: true, interval: const Duration(milliseconds: 100));

    final alwaysOn = AlwaysOnScreen(renderer);
    alwaysOn.setIdleTimeoutMin(0); // immediate sleep
    alwaysOn.start();
    await Future.delayed(const Duration(milliseconds: 250));
    final afterSleep = sends;

    // Keep-alive should not send while sleeping
    await Future.delayed(const Duration(milliseconds: 250));
    expect(sends, afterSleep); // no new sends

    // forceFrame blocked while paused
    renderer.forceFrame();
    expect(sends, afterSleep);

    // Wake resumes
    alwaysOn.notifyInput();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(sends, greaterThan(afterSleep));

    alwaysOn.stop();
    renderer.dispose();
  });
}
