/// Touch input provider (phone touchscreen).
/// Maps taps/swipes to navigation actions.
library;

import 'dart:async';
import 'input_event.dart';
import 'input_provider.dart';

class TouchInput implements InputProvider {
  final StreamController<InputEvent> _c = StreamController<InputEvent>.broadcast();

  @override
  String get name => 'Touch';
  @override
  InputType get type => InputType.touch;
  @override
  Stream<InputEvent> get events => _c.stream;

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}

  void onTap() => _c.add(InputEventFactory.touch(InputAction.confirm));
  void onSwipeUp() => _c.add(InputEventFactory.touch(InputAction.up));
  void onSwipeDown() => _c.add(InputEventFactory.touch(InputAction.down));
  void onSwipeLeft() => _c.add(InputEventFactory.touch(InputAction.left));
  void onSwipeRight() => _c.add(InputEventFactory.touch(InputAction.right));
  void onBack() => _c.add(InputEventFactory.touch(InputAction.back));
}
