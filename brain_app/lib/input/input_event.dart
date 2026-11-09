/// Common input abstraction. Hardware-independent.
/// Physical buttons plug in via HudInputProvider without redesigning the UI.
library;

enum InputType {
  touch,
  keyboard,
  voice,
  gesture,
  hardware,
}

enum InputAction {
  up,
  down,
  left,
  right,
  confirm,
  back,
  home,
  voiceStart,
  voiceStop,
  custom,
}

class InputEvent {
  final InputType type;
  final InputAction action;
  final String? payload;
  final DateTime timestamp;

  InputEvent({required this.type, required this.action, this.payload, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class InputEventFactory {
  static InputEvent touch(InputAction a) => InputEvent(type: InputType.touch, action: a);
  static InputEvent keyboard(InputAction a) => InputEvent(type: InputType.keyboard, action: a);
  static InputEvent voice(InputAction a, {String? text}) =>
      InputEvent(type: InputType.voice, action: a, payload: text);
  static InputEvent gesture(InputAction a) => InputEvent(type: InputType.gesture, action: a);
  static InputEvent hardware(InputAction a, {String? code}) =>
      InputEvent(type: InputType.hardware, action: a, payload: code);
}
