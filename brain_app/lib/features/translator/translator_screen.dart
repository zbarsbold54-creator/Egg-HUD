/// Translator. STT + translation + language selection.
/// Prioritizes English, Mongolian, Chinese. Phone shows full UI,
/// glasses show most useful translation. Offline where engine exists.
library;

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key});

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final SpeechToText _stt = SpeechToText();
  String _original = '';
  String _translated = '';
  String _fromLang = 'en';
  String _toLang = 'mn';
  bool _listening = false;

  final List<String> _langs = ['en', 'mn', 'zh'];

  Future<void> _listen() async {
    await _stt.initialize();
    setState(() => _listening = true);
    await _stt.listen(
      listenOptions: SpeechListenOptions(localeId: _fromLang == 'en' ? 'en-US' : _fromLang == 'mn' ? 'mn-MN' : 'zh-CN'),
      onResult: (r) {
        setState(() => _original = r.recognizedWords);
        if (r.finalResult) {
          _translate();
        }
      },
    );
  }

  Future<void> _translate() async {
    // Translation provider interface. Production: plug in ML Kit (Android/iOS)
    // or a REST engine. Desktop: unavailable until engine configured.
    // Do not fake translation.
    setState(() {
      _translated = '[Translation engine not configured. Set up ML Kit or REST provider. Original: $_original]';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Translator')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                DropdownButton<String>(
                  value: _fromLang,
                  items: _langs.map((l) => DropdownMenuItem(value: l, child: Text(l.toUpperCase()))).toList(),
                  onChanged: (v) => setState(() => _fromLang = v!),
                ),
                const Icon(Icons.swap_horiz),
                DropdownButton<String>(
                  value: _toLang,
                  items: _langs.map((l) => DropdownMenuItem(value: l, child: Text(l.toUpperCase()))).toList(),
                  onChanged: (v) => setState(() => _toLang = v!),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(text: _original),
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Original', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _original = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _translated),
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Translated', border: OutlineInputBorder()),
              readOnly: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _listening ? null : _listen,
                  icon: const Icon(Icons.mic),
                  label: const Text('Speak'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _translate,
                  icon: const Icon(Icons.translate),
                  label: const Text('Translate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
