/// Audio device status display for Settings.
/// Shows actual detected mic/output devices via OS APIs.
/// HUD Egg is display-only — all audio via phone OS.
library;

import 'package:flutter/material.dart';
import '../../core/services/audio_device_service.dart';

class AudioDeviceStatus extends StatefulWidget {
  const AudioDeviceStatus({super.key});

  @override
  State<AudioDeviceStatus> createState() => _AudioDeviceStatusState();
}

class _AudioDeviceStatusState extends State<AudioDeviceStatus> {
  List<AudioDeviceInfo> _inputs = [];
  List<AudioDeviceInfo> _outputs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
    if (_loading) return const Text('Detecting audio devices...');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Microphone:', style: TextStyle(fontWeight: FontWeight.bold)),
        if (_inputs.isEmpty)
          const Text('No microphone detected.')
        else
          for (final d in _inputs)
            Text('• ${d.name} (${d.typeLabel}, ${d.capabilities})'),
        const SizedBox(height: 8),
        const Text('Output:', style: TextStyle(fontWeight: FontWeight.bold)),
        if (_outputs.isEmpty)
          const Text('No output detected.')
        else
          for (final d in _outputs)
            Text('• ${d.name} (${d.typeLabel}, ${d.capabilities})'),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}
