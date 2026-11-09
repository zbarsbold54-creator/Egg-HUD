/// Music controls with animated frequency bars (lows/bass/mids/highs).
/// Bars animate while playing — visualizer, not real FFT (ponytail: minimal).
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});
  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final String _track = 'No track';
  final String _artist = '';
  bool _playing = false;
  double _progress = 0;
  double _volume = 0.5;
  static const _volChannel = MethodChannel('com.jarvis.brain_app/volume');

  @override
  void initState() {
    super.initState();
    _loadVolume();
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
  }
  Timer? _timer;
  final List<double> _bars = List.generate(16, (_) => 0.2);
  final _rand = math.Random();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    _timer?.cancel();
    if (_playing) {
      _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        setState(() {
          for (int i = 0; i < _bars.length; i++) {
            // Bass (low indices) moves more, highs less — fake spectrum
            final energy = 1.0 - (i / _bars.length) * 0.6;
            _bars[i] = (_bars[i] + (_rand.nextDouble() * energy * 0.5)).clamp(0.05, 1.0);
            _bars[i] *= 0.85;
          }
          _progress = (_progress + 0.005) % 1.0;
        });
      });
    }
  }

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
            // Animated bars: lows | bass | mids | highs
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
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.skip_previous), onPressed: () {}),
                IconButton(
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 48),
                  onPressed: _togglePlay,
                ),
                IconButton(icon: const Icon(Icons.skip_next), onPressed: () {}),
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
