/// Music: real playback via audioplayers + real phone volume.
/// Plays a test stream (SoundHelix sample). Bars animate while playing.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});
  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final AudioPlayer _player = AudioPlayer();
  static const _volChannel = MethodChannel('com.jarvis.brain_app/volume');
  // SoundHelix test track (public sample)
  static const _trackUrl = 'https://www.soundhelix.com/examples/soundhelix-songs-1.mp3';
  bool _playing = false;
  double _volume = 0.5;
  Timer? _timer;
  final List<double> _bars = List.generate(16, (_) => 0.2);
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _loadVolume();
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
      if (s == PlayerState.playing) { _startBars(); } else { _timer?.cancel(); }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadVolume() async {
    try {
      final v = await _volChannel.invokeMethod<double>('get');
      if (mounted && v != null) setState(() => _volume = v);
    } catch (_) {}
  }

  Future<void> _setVolume(double v) async {
    setState(() => _volume = v);
    try { await _volChannel.invokeMethod('set', {'value': v}); } catch (_) {}
    try { await _player.setVolume(v); } catch (_) {}
  }

  Future<void> _togglePlay() async {
    try {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.play(UrlSource(_trackUrl));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playback failed: $e')));
    }
  }

  void _startBars() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _bars.length; i++) {
          final energy = 1.0 - (i / _bars.length) * 0.6;
          _bars[i] = (_bars[i] + (_rand.nextDouble() * energy * 0.5)).clamp(0.05, 1.0);
          _bars[i] *= 0.85;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('SoundHelix Sample', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Test track — real playback'),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _bars.map((v) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: v * 110,
                    decoration: BoxDecoration(
                      color: _playing ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('LOW', style: TextStyle(fontSize: 10)),
                Text('BASS', style: TextStyle(fontSize: 10)),
                Text('MIDS', style: TextStyle(fontSize: 10)),
                Text('HIGH', style: TextStyle(fontSize: 10)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.skip_previous), onPressed: () async { try { await _player.seek(Duration.zero); } catch (_) {} }),
                IconButton(
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 48),
                  onPressed: _togglePlay,
                ),
                IconButton(icon: const Icon(Icons.skip_next), onPressed: () async { try { await _player.seek(const Duration(seconds: 30)); } catch (_) {} }),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.volume_down),
                Expanded(child: Slider(value: _volume, onChanged: _setVolume)),
                const Icon(Icons.volume_up),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
