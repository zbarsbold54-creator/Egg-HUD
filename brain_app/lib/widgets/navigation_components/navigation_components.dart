/// Navigation components for phone UI.
library;

import 'package:flutter/material.dart';

class ModuleGrid extends StatelessWidget {
  final List<ModuleItem> items;
  const ModuleGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return Semantics(
          button: true,
          label: item.label,
          child: Card(
          child: InkWell(
            onTap: item.onTap,
            // Accessibility: screen readers announce the module name.
            // (InkWell provides tap semantics; label is visible text.)
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 28),
                const SizedBox(height: 4),
                Text(item.label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

class ModuleItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const ModuleItem({required this.icon, required this.label, required this.onTap});
}
