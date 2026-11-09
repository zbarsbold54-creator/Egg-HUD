/// Reusable phone UI components that mirror the 128x64 pixel components.
library;

import 'package:flutter/material.dart';

class PixelCard extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  const PixelCard({super.key, required this.title, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class PixelProgressBar extends StatelessWidget {
  final double progress;
  const PixelProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(value: progress.clamp(0.0, 1.0));
  }
}

class PixelStatusDot extends StatelessWidget {
  final bool on;
  final Color? color;
  const PixelStatusDot({super.key, required this.on, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? (color ?? Colors.green) : Colors.grey,
      ),
    );
  }
}
