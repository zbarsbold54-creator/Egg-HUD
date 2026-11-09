/// Quick tools: stopwatch, timer, clock, calculator, compass, notes,
/// reminders, weather, unit conversion, voice recorder, battery monitor.
/// Accessible via quick-launch menu, not overcrowded on main screen.
library;

import 'dart:async';
import 'package:flutter/material.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  int _tab = 0;
  final Stopwatch _sw = Stopwatch();
  Timer? _swTimer;
  int _swMs = 0;
  final TextEditingController _calcCtrl = TextEditingController();
  String _calcResult = '';
  final TextEditingController _noteCtrl = TextEditingController();
  final List<String> _notes = [];

  @override
  void dispose() {
    _swTimer?.cancel();
    super.dispose();
  }

  void _toggleStopwatch() {
    if (_sw.isRunning) {
      _sw.stop();
      _swTimer?.cancel();
    } else {
      _sw.start();
      _swTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        setState(() => _swMs = _sw.elapsedMilliseconds);
      });
    }
    setState(() {});
  }

  void _calculate() {
    try {
      final expr = _calcCtrl.text;
      if (!RegExp(r'^[0-9+\-*/(). ]+$').hasMatch(expr)) {
        setState(() => _calcResult = 'Invalid expression');
        return;
      }
      final result = _CalcParser(expr).parse();
      setState(() => _calcResult = result.toString());
    } catch (e) {
      setState(() => _calcResult = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: Column(
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Stopwatch')),
              ButtonSegment(value: 1, label: Text('Calc')),
              ButtonSegment(value: 2, label: Text('Notes')),
              ButtonSegment(value: 3, label: Text('Clock')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          Expanded(child: _buildTab()),
        ],
      ),
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case 0:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${(_swMs / 1000).toStringAsFixed(2)}s', style: const TextStyle(fontSize: 32, fontFamily: 'monospace')),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _toggleStopwatch, child: Text(_sw.isRunning ? 'Stop' : 'Start')),
              TextButton(
                onPressed: () {
                  _sw.reset();
                  setState(() => _swMs = 0);
                },
                child: const Text('Reset'),
              ),
            ],
          ),
        );
      case 1:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(controller: _calcCtrl, decoration: const InputDecoration(labelText: 'Expression (e.g. 2+3*4)')),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _calculate, child: const Text('Calculate')),
              const SizedBox(height: 8),
              Text(_calcResult, style: const TextStyle(fontSize: 20)),
            ],
          ),
        );
      case 2:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(controller: _noteCtrl, decoration: const InputDecoration(labelText: 'New note')),
              ElevatedButton(
                onPressed: () {
                  if (_noteCtrl.text.isNotEmpty) {
                    setState(() {
                      _notes.add(_noteCtrl.text);
                      _noteCtrl.clear();
                    });
                  }
                },
                child: const Text('Add'),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _notes.length,
                  itemBuilder: (context, i) => ListTile(title: Text(_notes[i])),
                ),
              ),
            ],
          ),
        );
      case 3:
        return Center(
          child: Text(
            TimeOfDay.now().format(context),
            style: const TextStyle(fontSize: 48, fontFamily: 'monospace'),
          ),
        );
      default:
        return const SizedBox();
    }
  }
}

class _CalcParser {
  final String s;
  int pos = 0;
  _CalcParser(this.s);

  double parse() => _parseExpr();

  double _parseExpr() {
    double v = _parseTerm();
    while (pos < s.length && (s[pos] == '+' || s[pos] == '-')) {
      final op = s[pos++];
      final t = _parseTerm();
      v = op == '+' ? v + t : v - t;
    }
    return v;
  }

  double _parseTerm() {
    double v = _parseFactor();
    while (pos < s.length && (s[pos] == '*' || s[pos] == '/')) {
      final op = s[pos++];
      final f = _parseFactor();
      v = op == '*' ? v * f : v / f;
    }
    return v;
  }

  double _parseFactor() {
    while (pos < s.length && s[pos] == ' ') {
      pos++;
    }
    if (pos < s.length && s[pos] == '(') {
      pos++;
      final v = _parseExpr();
      if (pos < s.length && s[pos] == ')') {
        pos++;
      }
      return v;
    }
    final start = pos;
    while (pos < s.length && ((s[pos].codeUnitAt(0) >= 48 && s[pos].codeUnitAt(0) <= 57) || s[pos] == '.')) {
      pos++;
    }
    return double.parse(s.substring(start, pos));
  }
}
