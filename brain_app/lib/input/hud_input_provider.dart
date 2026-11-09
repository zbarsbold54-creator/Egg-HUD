/// Bridges HUD input WebSocket events into the central InputStateMachine.
/// Preserves press/release timing for Morse decoding. Never double-processes.
library;

import 'dart:async';
import '../connectivity/hud/hud_input_connection.dart';
import 'input_event.dart';
import 'input_provider.dart';
import 'input_state_machine.dart';

class HudInputProvider implements InputProvider {
  final HudInputConnection connection;
  final InputStateMachine stateMachine;
  final StreamController<InputEvent> _c = StreamController<InputEvent>.broadcast();
  StreamSubscription<HudInputEvent>? _sub;

  HudInputProvider({required this.connection, required this.stateMachine});

  @override
  String get name => 'HUD Controller';
  @override
  InputType get type => InputType.hardware;
  @override
  Stream<InputEvent> get events => _c.stream;

  @override
  Future<void> start() async {
    _sub = connection.events.listen((e) {
      if (e.type == 'button_down') {
        stateMachine.onButtonDown();
      } else if (e.type == 'button_up') {
        stateMachine.onButtonUpWithDuration(Duration(milliseconds: e.durationMs));
      }
    });
    stateMachine.events.listen((ev) {
      if (!_c.isClosed) _c.add(ev);
    });
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
