/// Input provider interface. All input sources implement this.
library;

import 'dart:async';
import 'input_event.dart';

abstract class InputProvider {
  String get name;
  InputType get type;
  Stream<InputEvent> get events;
  Future<void> start();
  Future<void> stop();
}
