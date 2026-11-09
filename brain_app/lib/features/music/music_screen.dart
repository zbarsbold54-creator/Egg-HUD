/// Music controls. Android media sessions via platform channel;
/// desktop shows unavailable state (does not claim support until tested).
library;

import 'package:flutter/material.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final String _track = 'No track';
  final String _artist = '';
  bool _playing = false;
  final double _progress = 0;
  double _volume = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_track, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(_artist),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.skip_previous), onPressed: () {}),
                IconButton(
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 48),
                  onPressed: () => setState(() => _playing = !_playing),
                ),
                IconButton(icon: const Icon(Icons.skip_next), onPressed: () {}),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.volume_down),
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: (v) => setState(() => _volume = v),
                  ),
                ),
                const Icon(Icons.volume_up),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Android media session integration via platform channel. Desktop: unavailable until tested.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
