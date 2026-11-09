/// Voice input provider (STT).
/// Push-to-talk by default. Continuous listening only if explicitly enabled.
/// No fake wake-word detection.
library;

import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'input_event.dart';
import 'input_provider.dart';

class VoiceInput implements InputProvider {
  final SpeechToText _stt = SpeechToText();
  final StreamController<InputEvent> _c = StreamController<InputEvent>.broadcast();
  bool _available = false;
  String _language = 'en-US';

  @override
  String get name => 'Voice';
  @override
  InputType get type => InputType.voice;
  @override
  Stream<InputEvent> get events => _c.stream;

  bool get available => _available;
  bool get isListening => _stt.isListening;

  void setLanguage(String lang) => _language = lang;

  @override
  Future<void> start() async {
    _available = await _stt.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          _c.add(InputEventFactory.voice(InputAction.voiceStop));
        }
      },
      onError: (_) {},
    );
  }

  @override
  Future<void> stop() async {
    await _stt.stop();
  }

  Future<void> startListening() async {
    if (!_available) return;
    _c.add(InputEventFactory.voice(InputAction.voiceStart));
    await _stt.listen(
      listenOptions: SpeechListenOptions(localeId: _language),
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _c.add(InputEventFactory.voice(InputAction.custom, text: result.recognizedWords));
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }
}
