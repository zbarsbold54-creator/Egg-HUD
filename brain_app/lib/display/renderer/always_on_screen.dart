/// Always-on HUD screen: time, connection status, music.
library;

import 'dart:async';
import 'display_renderer.dart';
import 'display_text.dart';

class AlwaysOnScreen {
  final DisplayRenderer renderer;
  Timer? _timer;
  String hudStatus = 'HUD: --';
  String controllerStatus = 'CTRL: --';
  String music = 'No track';

  AlwaysOnScreen(this.renderer);

  void start() {
    _draw();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _draw());
  }

  void stop() => _timer?.cancel();

  void _draw() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final canvas = renderer.canvas;
    canvas.clear();
    DisplayText.draw(canvas, 4, 0, '$hh:$mm', scale: 2);
    DisplayText.draw(canvas, 4, 20, hudStatus);
    DisplayText.draw(canvas, 4, 30, controllerStatus);
    DisplayText.draw(canvas, 4, 40, music);
    renderer.requestFrame();
  }
}
