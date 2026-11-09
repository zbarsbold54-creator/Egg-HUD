import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/input/input_state_machine.dart';

void main() {
  test('5s max-hold after 2s exit emits no Morse/select', () async {
    final sm = InputStateMachine();
    sm.setMode(InputMode.morseWriting);
    final events = <String>[];
    sm.events.listen((e) => events.add(e.payload ?? ''));

    // Press and hold: 2s exit fires, then 5s max-hold forces release.
    sm.onButtonDown();
    await Future.delayed(const Duration(milliseconds: 2100)); // 2s exit fires
    expect(events, contains('morse_exit'));

    events.clear();
    // Wait for 5s max-hold (total 7s from press, but max-hold is 5s from press)
    await Future.delayed(const Duration(milliseconds: 3000));
    // Max-hold forced release must NOT emit morse_dot/dash/select
    expect(events, isNot(contains('morse_dot')));
    expect(events, isNot(contains('morse_dash')));
    expect(events, isNot(contains('double_press')));
    expect(events, isNot(contains('short_press_next')));

    sm.dispose();
  });
}
