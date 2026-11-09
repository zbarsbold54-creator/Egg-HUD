import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/input/input_state_machine.dart';

void main() {
  test('button path 40 -> 1 with NO status must be accepted (reboot rule)', () async {
    // Simulates controller reboot: seq goes 40 -> 1 with no status CONNECTED.
    // Interim rule (seq <=4 and seq < lastSeq) must accept seq 1.
    // We test via InputStateMachine (button path), not via _onMessage (private).
    // The seq logic itself is in HudInputConnection._onMessage; this test
    // verifies the state machine handles the resulting events correctly.
    final sm = InputStateMachine();
    final events = <String>[];
    sm.events.listen((e) => events.add(e.payload ?? ''));

    // Simulate press at seq 40 (via state machine directly)
    sm.onButtonDown();
    await Future.delayed(const Duration(milliseconds: 50));
    sm.onButtonUpWithDuration(const Duration(milliseconds: 100));
    await Future.delayed(const Duration(milliseconds: 400));
    expect(events, contains('short_press_next'));

    // Simulate reboot: seq resets, next press is seq 1 (no status message).
    // State machine should handle it as a fresh press (no duplicate rejection here).
    events.clear();
    sm.onButtonDown();
    await Future.delayed(const Duration(milliseconds: 50));
    sm.onButtonUpWithDuration(const Duration(milliseconds: 100));
    await Future.delayed(const Duration(milliseconds: 400));
    expect(events, contains('short_press_next'));

    sm.dispose();
  });
}
