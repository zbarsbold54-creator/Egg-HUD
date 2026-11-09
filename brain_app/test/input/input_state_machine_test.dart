// Input state machine tests: verifies all combinations without hardware.
// Desktop simulator tests for Bluetooth HID button.
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/input/input_state_machine.dart';
import 'package:brain_app/input/input_event.dart';
import 'package:brain_app/input/morse_decoder.dart';

void main() {
  group('InputStateMachine - Normal Navigation', () {
    test('short press emits next after double-press window', () async {
      final sm = InputStateMachine();
      final events = <InputEvent>[];
      sm.events.listen(events.add);

      sm.onButtonDown();
      sm.onButtonUpWithDuration(const Duration(milliseconds: 100));
      // Wait for double-press window (350ms) + buffer
      await Future.delayed(const Duration(milliseconds: 500));
      expect(events.length, 1);
      expect(events.first.action, InputAction.down);
      expect(events.first.payload, 'short_press_next');
      sm.dispose();
    });

    test('double press emits select, not next', () async {
      final sm = InputStateMachine();
      final events = <InputEvent>[];
      sm.events.listen(events.add);

      sm.onButtonDown();
      sm.onButtonUpWithDuration(const Duration(milliseconds: 100));
      await Future.delayed(const Duration(milliseconds: 100));
      sm.onButtonDown();
      sm.onButtonUpWithDuration(const Duration(milliseconds: 100));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, 1);
      expect(events.first.action, InputAction.confirm);
      expect(events.first.payload, 'double_press');
      sm.dispose();
    });

    test('ordinary long press (500ms) is ignored', () async {
      final sm = InputStateMachine();
      final events = <InputEvent>[];
      sm.events.listen(events.add);

      sm.onButtonDown();
      sm.onButtonUpWithDuration(const Duration(milliseconds: 500));
      await Future.delayed(const Duration(milliseconds: 500));

      expect(events.isEmpty, true);
      sm.dispose();
    });

    test('very long press (2s) emits exit', () async {
      final sm = InputStateMachine();
      final events = <InputEvent>[];
      sm.events.listen(events.add);

      sm.onButtonDown();
      // Wait for very-long timer (2s)
      await Future.delayed(const Duration(milliseconds: 2100));
      sm.onButtonUpWithDuration(const Duration(seconds: 2));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, 1);
      expect(events.first.action, InputAction.back);
      sm.dispose();
    });
  });

  group('InputStateMachine - Morse Writing', () {
    test('short press in Morse mode emits dot, not navigation', () async {
      final sm = InputStateMachine();
      sm.setMode(InputMode.morseWriting);
      final events = <InputEvent>[];
      sm.events.listen(events.add);

      sm.onButtonDown();
      sm.onButtonUpWithDuration(const Duration(milliseconds: 100));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, 1);
      expect(events.first.payload, 'morse_dot');
      expect(sm.morsePresses.length, 1);
      sm.dispose();
    });

    test('long press in Morse mode emits dash, not navigation', () async {
      final sm = InputStateMachine();
      sm.setMode(InputMode.morseWriting);
      final events = <InputEvent>[];
      sm.events.listen(events.add);

      sm.onButtonDown();
      sm.onButtonUpWithDuration(const Duration(milliseconds: 300));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, 1);
      expect(events.first.payload, 'morse_dash');
      sm.dispose();
    });

    test('very long press in Morse mode exits, no Morse char', () async {
      final sm = InputStateMachine();
      sm.setMode(InputMode.morseWriting, saveScreen: 'teleprompter', savePosition: 42);
      final events = <InputEvent>[];
      sm.events.listen(events.add);

      sm.onButtonDown();
      await Future.delayed(const Duration(milliseconds: 2100));
      sm.onButtonUpWithDuration(const Duration(seconds: 2));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, 1);
      expect(events.first.payload, 'morse_exit');
      expect(sm.mode, InputMode.normalNavigation);
      expect(sm.savedScreen, 'teleprompter');
      expect(sm.savedPosition, 42);
      expect(sm.morsePresses.isEmpty, true); // No Morse char generated
      sm.dispose();
    });

    test('no simultaneous normal and Morse processing', () async {
      final sm = InputStateMachine();
      sm.setMode(InputMode.morseWriting);
      final events = <InputEvent>[];
      sm.events.listen(events.add);

      // Double-press pattern in Morse mode should NOT emit select
      sm.onButtonDown();
      sm.onButtonUpWithDuration(const Duration(milliseconds: 100));
      await Future.delayed(const Duration(milliseconds: 100));
      sm.onButtonDown();
      sm.onButtonUpWithDuration(const Duration(milliseconds: 100));
      await Future.delayed(const Duration(milliseconds: 100));

      // Should be 2 Morse dots, not 1 select
      expect(events.length, 2);
      expect(events.every((e) => e.payload == 'morse_dot'), true);
      sm.dispose();
    });
  });

  group('MorseDecoder', () {
    test('decodes A (.-)', () {
      expect(const MorseDecoder().decode('.-'), 'A');
    });

    test('decodes SOS (... --- ...)', () {
      const dec = MorseDecoder();
      expect(dec.decode('...'), 'S');
      expect(dec.decode('---'), 'O');
    });

    test('unknown code returns ?', () {
      expect(const MorseDecoder().decode('.-.-.-.-'), '?');
    });

    test('durations to Morse', () {
      const dec = MorseDecoder();
      final morse = dec.durationsToMorse([
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 300),
      ]);
      expect(morse, '.-');
    });
  });
}
