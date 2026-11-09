import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/connectivity/hud/hud_input_connection.dart';
import 'package:brain_app/input/input_state_machine.dart';

void main() {
  test('input state machine: short=next, double=select', () async {
    final sm = InputStateMachine();
    final events = <String>[];
    sm.events.listen((e) => events.add(e.payload ?? e.action.name));

    sm.onButtonDown();
    await Future.delayed(const Duration(milliseconds: 50));
    sm.onButtonUpWithDuration(const Duration(milliseconds: 100));
    await Future.delayed(const Duration(milliseconds: 400));
    expect(events, contains('short_press_next'));

    events.clear();
    sm.onButtonDown();
    await Future.delayed(const Duration(milliseconds: 50));
    sm.onButtonUpWithDuration(const Duration(milliseconds: 100));
    await Future.delayed(const Duration(milliseconds: 100));
    sm.onButtonDown();
    await Future.delayed(const Duration(milliseconds: 50));
    sm.onButtonUpWithDuration(const Duration(milliseconds: 100));
    await Future.delayed(const Duration(milliseconds: 100));
    expect(events, contains('double_press'));

    sm.dispose();
  });

  test('input state machine: Morse dot/dash', () async {
    final sm = InputStateMachine();
    sm.setMode(InputMode.morseWriting);
    final events = <String>[];
    sm.events.listen((e) => events.add(e.payload ?? ''));

    sm.onButtonDown();
    await Future.delayed(const Duration(milliseconds: 50));
    sm.onButtonUpWithDuration(const Duration(milliseconds: 100));
    await Future.delayed(const Duration(milliseconds: 50));
    expect(events, contains('morse_dot'));

    events.clear();
    sm.onButtonDown();
    await Future.delayed(const Duration(milliseconds: 50));
    sm.onButtonUpWithDuration(const Duration(milliseconds: 300));
    await Future.delayed(const Duration(milliseconds: 50));
    expect(events, contains('morse_dash'));

    sm.dispose();
  });

  test('controller status enum has all 6 states', () {
    expect(ControllerStatus.values.length, 6);
    expect(ControllerStatus.values.map((e) => e.name),
        containsAll(['disconnected', 'searching', 'connecting', 'connected', 'reconnecting', 'error']));
  });
}
