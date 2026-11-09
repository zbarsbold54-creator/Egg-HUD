/// Future hardware input adapter (physical button, Bluetooth remote,
/// clicker, touchpad, sensor device). Replaceable without UI redesign.
/// Currently a no-op placeholder — the app is fully usable without it.
library;

import 'dart:async';
import 'input_event.dart';
import 'input_provider.dart';

class FutureHardwareInput implements InputProvider {
  final StreamController<InputEvent> _c = StreamController<InputEvent>.broadcast();

  @override
  String get name => 'Future Hardware';
  @override
  InputType get type => InputType.hardware;
  @override
  Stream<InputEvent> get events => _c.stream;

  @override
  Future<void> start() async {
    // No hardware connected. Future implementation: BLE/USB HID listener.
  }

  @override
  Future<void> stop() async {}

  /// Called by future hardware adapter when a button is pressed.
  void onHardwareButton(String code) {
    _c.add(InputEventFactory.hardware(InputAction.custom, code: code));
  }
}
