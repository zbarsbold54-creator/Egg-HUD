/// EDITH assistant interface. Phone is the large conversation UI,
/// glasses show compact status. STT -> HA -> Hermes -> TTS.
/// EDITH is the display name and voice identity; Hermes on ZimaOS
/// remains the underlying AI intelligence (reasoning, memory, tools).
/// EDITH personality: calm, intelligent, precise, confident, slightly witty.
/// This is a presentation layer — Hermes execution behavior is unchanged.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../connectivity/home_assistant/home_assistant_client.dart';
import '../../connectivity/hermes/hermes_adapter.dart';
import '../../core/storage/settings_store.dart';
import '../../display/renderer/display_animation.dart';
import '../../widgets/character/edith_character.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final List<_Msg> _messages = [];
  final TextEditingController _input = TextEditingController();
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _listening = false;
  bool _busy = false;
  String _recognized = '';
  EdithState _state = EdithState.idle;
  int _requestId = 0;
  String _interruptNote = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    await _stt.initialize();
    await _tts.setLanguage('en-US');
    final rate = await SettingsStore.getSpeechRate();
    await _tts.setSpeechRate(rate);
    final vol = await SettingsStore.getSpeechVolume();
    await _tts.setVolume(vol);
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _stt.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }
    final lang = await SettingsStore.getRecognitionLanguage();
    setState(() {
      _listening = true;
      _state = EdithState.listening;
      _recognized = '';
    });
    await _stt.listen(
      listenOptions: SpeechListenOptions(localeId: lang),
      onResult: (r) {
        setState(() => _recognized = r.recognizedWords);
        if (r.finalResult && r.recognizedWords.isNotEmpty) {
          _send(r.recognizedWords);
        }
      },
    );
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _busy) return;
    final myId = ++_requestId;
    setState(() {
      _messages.add(_Msg(text, true));
      _busy = true;
      _state = EdithState.thinking;
      _listening = false;
      _interruptNote = '';
    });
    _input.clear();
    try {
      final haUrl = await SettingsStore.getHaUrl();
      final token = await SettingsStore.getHaToken();
      final agentId = await SettingsStore.getHaAgentId();
      final ha = HomeAssistantClient(baseUrl: haUrl, token: token, agentId: agentId);
      final hermes = HermesAdapter(ha: ha);
      final response = await hermes.sendRequest(
        text,
        onStage: (stage) {
          if (myId != _requestId) return; // interrupted — ignore late stages
          setState(() {
            _state = switch (stage) {
              HermesActivityStage.understanding => EdithState.thinking,
              HermesActivityStage.preparingResponse => EdithState.speaking,
              HermesActivityStage.completed => EdithState.success,
              HermesActivityStage.failed => EdithState.error,
              _ => EdithState.processing,
            };
          });
        },
      );
      if (myId != _requestId || !mounted) return; // interrupted — discard late response
      setState(() {
        _messages.add(_Msg(response, false));
        _state = EdithState.success;
      });
      await _tts.speak(response);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && myId == _requestId) setState(() => _state = EdithState.idle);
      });
    } catch (e) {
      if (myId != _requestId || !mounted) return;
      setState(() {
        _messages.add(_Msg('Error: $e', false));
        _state = EdithState.error;
      });
    } finally {
      if (mounted && myId == _requestId) setState(() => _busy = false);
    }
  }

  /// Interrupt stops LOCAL speech (TTS/STT) immediately.
  /// It does NOT cancel remote Hermes execution — HA conversation is a
  /// single HTTP POST with no cancel API. The late response is discarded
  /// locally (requestId check above), but Hermes may still complete
  /// server-side. This distinction is shown in the UI.
  Future<void> _interrupt() async {
    _requestId++; // invalidate in-flight request
    await _tts.stop();
    await _stt.stop();
    setState(() {
      _busy = false;
      _listening = false;
      _interruptNote = 'Speech stopped. Remote Hermes execution may continue server-side (no cancel API).';
      _state = EdithState.idle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EDITH'),
        actions: [
          IconButton(icon: const Icon(Icons.stop), onPressed: _interrupt, tooltip: 'Stop speech (remote Hermes may continue)'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: EdithCharacter(state: _state, size: 100),
          ),
          if (_recognized.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Heard: $_recognized', style: const TextStyle(fontStyle: FontStyle.italic)),
            ),
          if (_interruptNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_interruptNote, style: const TextStyle(fontSize: 11, color: Colors.orange)),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                return ListTile(
                  title: Text(m.text),
                  subtitle: Text(m.fromUser ? 'You' : 'EDITH'),
                  tileColor: m.fromUser ? Colors.blueGrey.shade900 : null,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_listening ? Icons.mic_off : Icons.mic),
                  onPressed: _toggleListen,
                  tooltip: 'Push to talk',
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(hintText: 'Type to EDITH...', border: OutlineInputBorder()),
                    onSubmitted: _send,
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: () => _send(_input.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  final String text;
  final bool fromUser;
  _Msg(this.text, this.fromUser);
}
