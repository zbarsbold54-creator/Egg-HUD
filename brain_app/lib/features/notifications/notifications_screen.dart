/// Messages and notifications. Requests POST_NOTIFICATIONS on Android 13+.
/// Mirroring (reading other apps' notifications) needs NotificationListenerService
/// (Android system service, requires user grant in Settings). Stubbed behind
/// _mirroringEnabled setting — not implemented.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationItem {
  final String sender;
  final String app;
  final String preview;
  final DateTime time;
  final int priority;
  const NotificationItem({required this.sender, required this.app, required this.preview, required this.time, this.priority = 1});
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _channel = MethodChannel('com.jarvis.brain_app/notifications');
  final List<NotificationItem> _items = [];
  bool _granted = false;
  bool _checking = true;
  bool _mirroringEnabled = false; // stub: needs NotificationListenerService

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final ok = await _channel.invokeMethod<bool>('check') ?? false;
      if (!mounted) return;
      setState(() { _granted = ok; _checking = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _granted = false; _checking = false; });
    }
  }

  Future<void> _request() async {
    try {
      await _channel.invokeMethod<bool>('request');
      await Future.delayed(const Duration(milliseconds: 500));
      await _check();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_checking) const Center(child: CircularProgressIndicator()),
            if (!_checking && !_granted)
              Card(
                child: ListTile(
                  title: const Text('Notification access not granted'),
                  subtitle: const Text('Tap Request to allow notifications.'),
                  trailing: ElevatedButton(onPressed: _request, child: const Text('Request')),
                ),
              ),
            if (!_checking && _granted)
              Card(
                child: ListTile(
                  title: const Text('Notifications enabled'),
                  subtitle: const Text('Mirroring other apps needs NotificationListenerService (system grant). Not implemented — stub.'),
                  trailing: Switch(value: _mirroringEnabled, onChanged: (v) => setState(() => _mirroringEnabled = v)),
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
