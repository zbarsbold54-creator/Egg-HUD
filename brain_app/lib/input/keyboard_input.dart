/// Desktop keyboard/mouse input provider.
/// Arrow keys navigate, Enter confirms, Esc goes back, H goes home.
library;

import 'dart:async';
import 'package:flutter/services.dart';
import 'input_event.dart';
import 'input_provider.dart';

class KeyboardInput implements InputProvider {
  final StreamController<InputEvent> _c = StreamController<InputEvent>.broadcast();

  @override
  String get name => 'Keyboard';
  @override
  InputType get type => InputType.keyboard;
  @override
  Stream<InputEvent> get events => _c.stream;

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}

  bool handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _c.add(InputEventFactory.keyboard(InputAction.up));
        return true;
      case LogicalKeyboardKey.arrowDown:
        _c.add(InputEventFactory.keyboard(InputAction.down));
        return true;
      case LogicalKeyboardKey.arrowLeft:
        _c.add(InputEventFactory.keyboard(InputAction.left));
        return true;
      case LogicalKeyboardKey.arrowRight:
        _c.add(InputEventFactory.keyboard(InputAction.right));
        return true;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        _c.add(InputEventFactory.keyboard(InputAction.confirm));
        return true;
      case LogicalKeyboardKey.escape:
        _c.add(InputEventFactory.keyboard(InputAction.back));
        return true;
      case LogicalKeyboardKey.keyH:
        _c.add(InputEventFactory.keyboard(InputAction.home));
        return true;
      default:
        return false;
    }
  }
}
