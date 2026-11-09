/// Single Bluetooth HID mouse button input.
///
/// The button is a standard BLE HID mouse (left-click only) paired
/// directly to the phone at OS level — like any Bluetooth mouse.
/// No custom GATT, no BLE scanning/pairing in the app.
///
/// The app receives ordinary OS pointer events (click). This provider
/// translates click down/up into [InputStateMachine] press/release
/// with timing preservation for Morse decoding.
///
/// Do NOT implement or depend on the deferred Palm Mouse.
/// Input source is a simple standard Bluetooth HID button.
library;

import 'dart:async';
import 'input_event.dart';
import 'input_provider.dart';
import 'input_state_machine.dart';

class BluetoothButtonInput implements InputProvider {
  final InputStateMachine _stateMachine = InputStateMachine();
  DateTime? _pressStart;

  @override
  String get name => 'Bluetooth Button';
  @override
  InputType get type => InputType.hardware;
  @override
  Stream<InputEvent> get events => _stateMachine.events;

  InputStateMachine get stateMachine => _stateMachine;
  InputMode get mode => _stateMachine.mode;

  void setMode(InputMode mode, {String? saveScreen, int savePosition = 0}) {
    _stateMachine.setMode(mode, saveScreen: saveScreen, savePosition: savePosition);
  }

  void setTiming(InputTimingConfig config) => _stateMachine.setTiming(config);

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}

  /// Called on OS pointer down (button press).
  void onPointerDown() {
    _pressStart = DateTime.now();
    _stateMachine.onButtonDown();
  }

  /// Called on OS pointer up (button release).
  void onPointerUp() {
    if (_pressStart == null) return;
    final duration = DateTime.now().difference(_pressStart!);
    _pressStart = null;
    _stateMachine.onButtonUpWithDuration(duration);
  }

  /// For desktop simulator: simulate a press with given duration.
  void simulatePress(Duration duration) {
    _stateMachine.onButtonDown();
    // Very-long timer will fire if duration >= 2s (handled by state machine)
    // For simulation, directly call release with duration
    _stateMachine.onButtonUpWithDuration(duration);
  }

  void dispose() => _stateMachine.dispose();
}
