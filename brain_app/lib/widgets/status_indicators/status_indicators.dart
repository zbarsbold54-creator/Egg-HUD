/// Status indicators for dashboard top bar.
library;

import 'package:flutter/material.dart';

class StatusBar extends StatelessWidget {
  final String clock;
  final double? phoneBattery;
  final bool hudConnected;
  final bool wifiConnected;
  final bool bluetoothConnected;
  final bool assistantConnected;

  const StatusBar({
    super.key,
    required this.clock,
    this.phoneBattery,
    required this.hudConnected,
    required this.wifiConnected,
    required this.bluetoothConnected,
    required this.assistantConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(clock, style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
        Row(
          children: [
            _dot(hudConnected, Icons.monitor),
            const SizedBox(width: 8),
            _dot(wifiConnected, Icons.wifi),
            const SizedBox(width: 8),
            _dot(bluetoothConnected, Icons.bluetooth),
            const SizedBox(width: 8),
            _dot(assistantConnected, Icons.smart_toy),
            if (phoneBattery != null) ...[
              const SizedBox(width: 8),
              Text('${(phoneBattery! * 100).round()}%', style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _dot(bool on, IconData icon) {
    return Icon(icon, size: 16, color: on ? Colors.green : Colors.grey);
  }
}
