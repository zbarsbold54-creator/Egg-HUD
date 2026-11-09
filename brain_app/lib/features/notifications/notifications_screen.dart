/// Messages and notifications. Android notification access where permitted.
/// Desktop shows unavailable state. Does not collect/transmit contents unnecessarily.
library;

import 'package:flutter/material.dart';

class NotificationItem {
  final String sender;
  final String app;
  final String preview;
  final DateTime time;
  final int priority; // 0 low, 1 normal, 2 high

  const NotificationItem({required this.sender, required this.app, required this.preview, required this.time, this.priority = 1});
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<NotificationItem> _items = [];
  bool _permissionGranted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_permissionGranted)
              Card(
                child: ListTile(
                  title: const Text('Notification access not granted'),
                  subtitle: const Text('Grant notification listener permission in Android Settings to show messages here.'),
                  trailing: ElevatedButton(
                    onPressed: () => setState(() => _permissionGranted = true),
                    child: const Text('Request'),
                  ),
                ),
              ),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('No notifications.'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final n = _items[i];
                        return ListTile(
                          title: Text('${n.sender} (${n.app})'),
                          subtitle: Text(n.preview),
                          trailing: Text('${n.time.hour}:${n.time.minute.toString().padLeft(2, '0')}'),
                          onTap: () {},
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
