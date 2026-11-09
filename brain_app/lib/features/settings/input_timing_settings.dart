/// Input timing configuration for Bluetooth HID button.
/// Short/double/very-long press thresholds, debouncing.
/// All thresholds configurable in Settings.
library;

import 'package:flutter/material.dart';

class InputTimingSettings extends StatefulWidget {
  const InputTimingSettings({super.key});

  @override
  State<InputTimingSettings> createState() => _InputTimingSettingsState();
}

class _InputTimingSettingsState extends State<InputTimingSettings> {
  double _shortMax = 400;
  double _doubleWindow = 350;
  double _veryLong = 2000;
  double _debounce = 50;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: const Text('Short press max (ms)'),
          subtitle: Slider(
            value: _shortMax,
            min: 100,
            max: 800,
            divisions: 14,
            label: '${_shortMax.round()}ms',
            onChanged: (v) => setState(() => _shortMax = v),
          ),
        ),
        ListTile(
          title: const Text('Double-press window (ms)'),
          subtitle: Slider(
            value: _doubleWindow,
            min: 150,
            max: 600,
            divisions: 9,
            label: '${_doubleWindow.round()}ms',
            onChanged: (v) => setState(() => _doubleWindow = v),
          ),
        ),
        ListTile(
          title: const Text('Very-long press / exit (ms)'),
          subtitle: Slider(
            value: _veryLong,
            min: 1000,
            max: 4000,
            divisions: 12,
            label: '${_veryLong.round()}ms',
            onChanged: (v) => setState(() => _veryLong = v),
          ),
        ),
        ListTile(
          title: const Text('Debounce (ms)'),
          subtitle: Slider(
            value: _debounce,
            min: 10,
            max: 200,
            divisions: 19,
            label: '${_debounce.round()}ms',
            onChanged: (v) => setState(() => _debounce = v),
          ),
        ),
        const Text(
          'Normal: short=next, double=select, 2s=exit. Morse: presses for code, 2s=exit (no char).',
          style: TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}
