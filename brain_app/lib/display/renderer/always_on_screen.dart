/// Always-on HUD screen: time, connection status, music.
/// Idle = no input for 60s. Pixel-shift + dim to avoid OLED burn-in.
library;

import 'dart:async';
import 'display_renderer.dart';
import 'display_text.dart';

class AlwaysOnScreen {
  final DisplayRenderer renderer;
  Timer? _timer;
  DateTime _lastInput = DateTime.now();
  int _idleTimeoutMin = 5;
  bool _sleeping = false;
  int _shiftX = 0;
  int _shiftY = 0;
  String hudStatus = 'HUD: --';
  String controllerStatus = 'CTRL: --';
  String music = 'No track';

  AlwaysOnScreen(this.renderer);

  void notifyInput() {
    _lastInput = DateTime.now();
    if (_sleeping) {
      _sleeping = false;
      renderer.setPaused(false);
      renderer.forceFrame(); // resume rendering
      // Wake press is consumed (no action) — it only wakes the display.
    }
  }

  void setIdleTimeoutMin(int m) => _idleTimeoutMin = m;

  void start() {
    _draw();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _draw());
  }

  void stop() => _timer?.cancel();

  void _draw() {
    final now = DateTime.now();
    // Tier 3: N minutes no input -> blank frame + stop (firmware sleeps)
    if (now.difference(_lastInput) > Duration(minutes: _idleTimeoutMin)) {
      if (!_sleeping) {
        _sleeping = true;
        renderer.canvas.clear();
        renderer.forceFrame(); // one blank frame
        renderer.setPaused(true); // then pause keep-alive + forceFrame
      }
      return; // stop sending frames
    }
    final idle = now.difference(_lastInput) > const Duration(seconds: 60);
    // Pixel-shift every draw when idle (burn-in prevention)
    if (idle) {
      _shiftX = (_shiftX + 1) % 4;
      _shiftY = (_shiftY + 1) % 4;
    } else {
      _shiftX = 0;
      _shiftY = 0;
    }
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final canvas = renderer.canvas;
    canvas.clear();
    // Dim when idle: draw every other pixel (checker dim)
    DisplayText.draw(canvas, 4 + _shiftX, 0 + _shiftY, '$hh:$mm', scale: 2);
    DisplayText.draw(canvas, 4 + _shiftX, 20 + _shiftY, hudStatus);
    DisplayText.draw(canvas, 4 + _shiftX, 30 + _shiftY, controllerStatus);
    DisplayText.draw(canvas, 4 + _shiftX, 40 + _shiftY, music);
    if (idle) {
      // Dim: clear every other row (simple dim, no threshold needed)
      for (int y = 1; y < 64; y += 2) {
        for (int x = 0; x < 128; x++) {
          canvas.setPixel(x, y, false);
        }
      }
    }
    renderer.requestFrame();
  }
}
