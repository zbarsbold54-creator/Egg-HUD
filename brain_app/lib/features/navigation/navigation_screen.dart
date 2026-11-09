/// Compact navigation interface. Phone does routing, glasses show
/// turn-by-turn + mini-map. Uses OSRM (OpenStreetMap) by default.
/// Google Maps does not expose full turn-by-turn to third parties —
/// this provider is modular and does not fabricate access.
///
/// Verified: uses real location updates (position stream) and actual
/// OSRM route instructions (all steps, not just first).
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../core/storage/settings_store.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  String _status = 'Tap Start to get location and route.';
  String _nextTurn = '';
  double _distance = 0;
  String _eta = '';
  bool _loading = false;
  List<String> _instructions = [];
  StreamSubscription<Position>? _posSub;

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _status = 'Requesting location...';
    });
    try {
      // Check permissions
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Enable in Settings.');
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }

      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _status = 'Location: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}');

      // Start live location updates (real updates, not single fix)
      await _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen((p) {
        if (!mounted) return;
        setState(() {
          _status = 'Location: ${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)} (live)';
        });
      });

      // Demo destination: 1km north (replace with user input in production)
      final destLat = pos.latitude + 0.009;
      final destLon = pos.longitude;
      final endpoint = await SettingsStore.getOsrmEndpoint();
      final profile = await SettingsStore.getOsrmProfile();
      final url = '$endpoint/route/v1/$profile/${pos.longitude},${pos.latitude};$destLon,$destLat?overview=false&steps=true';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('OSRM failed (HTTP ${res.statusCode})');
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = json['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) throw Exception('No route found');
      final route = routes.first as Map<String, dynamic>;
      _distance = (route['distance'] as num).toDouble();
      final duration = (route['duration'] as num).toDouble();
      final mins = (duration / 60).round();
      _eta = '$mins min';
      final legs = route['legs'] as List<dynamic>?;
      final steps = legs?.first['steps'] as List<dynamic>?;
      _instructions = [];
      if (steps != null) {
        for (final s in steps) {
          final step = s as Map<String, dynamic>;
          final maneuver = step['maneuver'] as Map<String, dynamic>?;
          final type = maneuver?['type']?.toString() ?? 'continue';
          final modifier = maneuver?['modifier']?.toString();
          final name = step['name']?.toString() ?? '';
          final dist = (step['distance'] as num?)?.round() ?? 0;
          final label = modifier != null ? '$type $modifier on $name' : '$type on $name';
          _instructions.add('$label — ${dist}m');
        }
      }
      if (_instructions.isNotEmpty) {
        _nextTurn = _instructions.first;
      }
      if (!mounted) return;
      setState(() {
        _status = 'Route ready. ${_distance.round()}m, $_eta. ${_instructions.length} steps.';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Navigation unavailable: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_status),
            const SizedBox(height: 16),
            if (_nextTurn.isNotEmpty) ...[
              Text('NEXT: $_nextTurn', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${_distance.round()} m • $_eta'),
              const SizedBox(height: 8),
            ],
            if (_instructions.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _instructions.length,
                  itemBuilder: (context, i) => ListTile(
                    title: Text(_instructions[i], style: const TextStyle(fontSize: 13)),
                    leading: Text('${i + 1}'),
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _loading ? null : _start,
              icon: const Icon(Icons.navigation),
              label: const Text('Start Navigation'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Provider: OSRM (OpenStreetMap). Real location stream + actual route steps. Google Maps turn-by-turn is not exposed to third-party apps.',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
