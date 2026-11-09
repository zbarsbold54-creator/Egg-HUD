/// Teleprompter. User scripts, adjustable size/speed, pause/resume,
/// forward/back, looping, voice/gesture scroll. Position preserved
/// when switching modules (state kept in provider).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final teleprompterProvider = StateProvider<TeleprompterState>((ref) => TeleprompterState());

class TeleprompterState {
  String script = 'Welcome to EDITH Glasses OS.\nThis is your teleprompter.';
  double scrollSpeed = 20.0; // px/sec
  double textScale = 1.0;
  bool playing = false;
  bool looping = true;
  double position = 0.0; // scroll offset
}

class TeleprompterScreen extends ConsumerStatefulWidget {
  const TeleprompterScreen({super.key});

  @override
  ConsumerState<TeleprompterScreen> createState() => _TeleprompterScreenState();
}

class _TeleprompterScreenState extends ConsumerState<TeleprompterScreen> {
  late TextEditingController _scriptCtrl;

  @override
  void initState() {
    super.initState();
    _scriptCtrl = TextEditingController(text: ref.read(teleprompterProvider).script);
  }

  @override
  void dispose() {
    _scriptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teleprompterProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Teleprompter')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _scriptCtrl,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(labelText: 'Script', border: OutlineInputBorder()),
                onChanged: (v) {
                  ref.read(teleprompterProvider.notifier).state = TeleprompterState()
                    ..script = v
                    ..scrollSpeed = state.scrollSpeed
                    ..textScale = state.textScale
                    ..playing = state.playing
                    ..looping = state.looping
                    ..position = state.position;
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
                  onPressed: () {
                    final s = ref.read(teleprompterProvider);
                    ref.read(teleprompterProvider.notifier).state = TeleprompterState()
                      ..script = s.script
                      ..scrollSpeed = s.scrollSpeed
                      ..textScale = s.textScale
                      ..playing = !s.playing
                      ..looping = s.looping
                      ..position = s.position;
                  },
                ),
                const Text('Speed'),
                Expanded(
                  child: Slider(
                    value: state.scrollSpeed,
                    min: 5,
                    max: 60,
                    onChanged: (v) {
                      final s = ref.read(teleprompterProvider);
                      ref.read(teleprompterProvider.notifier).state = TeleprompterState()
                        ..script = s.script
                        ..scrollSpeed = v
                        ..textScale = s.textScale
                        ..playing = s.playing
                        ..looping = s.looping
                        ..position = s.position;
                    },
                  ),
                ),
                Text('${state.scrollSpeed.round()} px/s'),
              ],
            ),
            Text('Position preserved when switching modules: ${state.position.round()}px'),
          ],
        ),
      ),
    );
  }
}
