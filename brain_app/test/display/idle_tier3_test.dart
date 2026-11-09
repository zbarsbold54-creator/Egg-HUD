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
    alwaysOn.setIdleTimeoutMin(0);
    alwaysOn.start();
    await Future.delayed(const Duration(milliseconds: 300));
    final afterSleep = sends;

    // Keep-alive should be blocked while sleeping (allow 2 boundary ticks for CI jitter)
    await Future.delayed(const Duration(milliseconds: 300));
    expect(sends - afterSleep, lessThanOrEqualTo(2));

    // forceFrame blocked while paused
    final beforeForce = sends;
    renderer.forceFrame();
    expect(sends, beforeForce);

    // Wake resumes
    alwaysOn.notifyInput();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(sends, greaterThan(beforeForce));

    alwaysOn.stop();
    renderer.dispose();
  });
}
