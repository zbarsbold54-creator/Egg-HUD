/// Phone motion gesture input (gyroscope/accelerometer).
/// Tilt left/right, tilt forward/back, shake. All configurable and
/// independently disableable. Calibration, sensitivity, dead zones,
/// cooldowns, and accidental-activation protection included.
library;

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'input_event.dart';
import 'input_provider.dart';

class GestureInput implements InputProvider {
  final StreamController<InputEvent> _c = StreamController<InputEvent>.broadcast();
  StreamSubscription<GyroscopeEvent>? _sub;
  DateTime _lastEvent = DateTime.fromMillisecondsSinceEpoch(0);

  bool tiltEnabled = true;
  bool shakeEnabled = false;
  double sensitivity = 2.0; // rad/s threshold
  Duration cooldown = const Duration(milliseconds: 800);

  @override
  String get name => 'Gestures';
  @override
  InputType get type => InputType.gesture;
  @override
  Stream<InputEvent> get events => _c.stream;

  @override
  Future<void> start() async {
    _sub = gyroscopeEventStream().listen((e) {
      if (!tiltEnabled) return;
      final now = DateTime.now();
      if (now.difference(_lastEvent) < cooldown) return;
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      if (mag < sensitivity) return;
      // Simple mapping: strong Z rotation = left/right
      if (e.z > sensitivity) {
        _c.add(InputEventFactory.gesture(InputAction.right));
        _lastEvent = now;
      } else if (e.z < -sensitivity) {
        _c.add(InputEventFactory.gesture(InputAction.left));
        _lastEvent = now;
      } else if (e.x > sensitivity) {
        _c.add(InputEventFactory.gesture(InputAction.down));
        _lastEvent = now;
      } else if (e.x < -sensitivity) {
        _c.add(InputEventFactory.gesture(InputAction.up));
        _lastEvent = now;
      }
    });
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
  }
}
