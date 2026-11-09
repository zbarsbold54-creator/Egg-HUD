/// Sound controls. Volume, mute, audio output, mic status.
/// HUD Egg is display-only (no mic/speaker). All audio via phone OS.
/// Respects Android audio restrictions and desktop limitations.
library;

import 'package:flutter/material.dart';
import '../../core/services/audio_device_service.dart';

class SoundScreen extends StatefulWidget {
  const SoundScreen({super.key});

  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> {
  double _volume = 0.5;
  bool _muted = false;
  List<AudioDeviceInfo> _inputs = [];
  List<AudioDeviceInfo> _outputs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final inputs = await AudioDeviceService.getInputDevices();
    final outputs = await AudioDeviceService.getOutputDevices();
    setState(() {
      _inputs = inputs;
      _outputs = outputs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sound')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.volume_down),
                Expanded(
                  child: Slider(
                    value: _muted ? 0 : _volume,
                    onChanged: (v) => setState(() {
                      _volume = v;
                      _muted = v == 0;
                    }),
                  ),
                ),
                const Icon(Icons.volume_up),
                IconButton(
                  icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                  onPressed: () => setState(() => _muted = !_muted),
                ),
              ],
            ),
            const Divider(),
            const Text('Microphone (phone OS)', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_loading)
              const Text('Detecting devices...')
            else if (_inputs.isEmpty)
              const Text('No microphone detected. Check permissions.')
            else
              for (final d in _inputs)
                ListTile(
                  leading: Icon(d.isBluetooth ? Icons.bluetooth : Icons.mic),
                  title: Text(d.name),
                  subtitle: Text('${d.typeLabel} • ${d.capabilities}'),
                ),
            const Divider(),
            const Text('Audio Output (phone OS)', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_loading)
              const Text('Detecting devices...')
            else if (_outputs.isEmpty)
              const Text('No output detected.')
            else
              for (final d in _outputs)
                ListTile(
                  leading: Icon(d.isBluetooth ? Icons.bluetooth : Icons.speaker),
                  title: Text(d.name),
                  subtitle: Text('${d.typeLabel} • ${d.capabilities}'),
                ),
            const SizedBox(height: 16),
            const Text(
              'HUD Egg is display-only (no mic/speaker). Audio via phone OS. '
              'Bluetooth earbuds may have mic+speaker; some headphones are output-only. '
              'Android manages routing. No custom audio stack.',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
