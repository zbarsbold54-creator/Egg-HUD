import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:brain_app/input/input_state_machine.dart';

void main() {
  test('5s max-hold after 2s exit emits no Morse/select', () {
    fakeAsync((async) {
      final sm = InputStateMachine();
      sm.setMode(InputMode.morseWriting);
      final events = <String>[];
      sm.events.listen((e) => events.add(e.payload ?? ''));

      sm.onButtonDown();
      async.elapse(const Duration(milliseconds: 2100)); // 2s exit fires
      expect(events, contains('morse_exit'));

      events.clear();
      async.elapse(const Duration(milliseconds: 3000)); // 5s max-hold fires
      expect(events, isNot(contains('morse_dot')));
      expect(events, isNot(contains('morse_dash')));
      expect(events, isNot(contains('double_press')));
      expect(events, isNot(contains('short_press_next')));

      sm.dispose();
    });
  });
}
