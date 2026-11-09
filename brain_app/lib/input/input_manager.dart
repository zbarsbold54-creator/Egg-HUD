/// Central input manager. Routes [InputEvent]s from all providers
/// to the currently active screen. Provides focus navigation so future
/// simple hardware buttons can navigate without redesign.
library;

import 'dart:async';
import 'input_event.dart';
import 'input_provider.dart';

class InputManager {
  final List<InputProvider> _providers = [];
  final StreamController<InputEvent> _controller = StreamController<InputEvent>.broadcast();

  Stream<InputEvent> get events => _controller.stream;

  void register(InputProvider p) {
    _providers.add(p);
    p.events.listen((e) {
      if (!_controller.isClosed) _controller.add(e);
    });
  }

  void unregister(InputProvider p) => _providers.remove(p);

  Future<void> startAll() async {
    for (final p in _providers) {
      await p.start();
    }
  }

  Future<void> stopAll() async {
    for (final p in _providers) {
      await p.stop();
    }
  }

  void dispose() {
    _controller.close();
  }
}
