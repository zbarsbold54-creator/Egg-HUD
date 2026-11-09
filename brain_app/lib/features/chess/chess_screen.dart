/// Chess. Monochrome board on glasses, larger board on phone.
/// Uses chess package for rules. Point+click moves (no typing).
library;

import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;

class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key});

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  final chess_lib.Chess _game = chess_lib.Chess();
  String? _selected;
  final List<String> _history = [];

  String _symbol(chess_lib.Piece? piece) {
    if (piece == null) return '';
    final white = piece.color == chess_lib.Color.WHITE;
    switch (piece.type) {
      case chess_lib.PieceType.KING: return white ? '♔' : '♚';
      case chess_lib.PieceType.QUEEN: return white ? '♕' : '♛';
      case chess_lib.PieceType.ROOK: return white ? '♖' : '♜';
      case chess_lib.PieceType.BISHOP: return white ? '♗' : '♝';
      case chess_lib.PieceType.KNIGHT: return white ? '♘' : '♞';
      case chess_lib.PieceType.PAWN: return white ? '♙' : '♟';
    }
    return '';
  }

  void _onSquare(String sq) {
    if (_selected == null) {
      final piece = _game.get(sq);
      if (piece != null) setState(() => _selected = sq);
    } else {
      final move = _game.move({'from': _selected!, 'to': sq, 'promotion': 'q'});
      if (move) {
        _history.add('${_selected!}-$sq');
        setState(() => _selected = null);
      } else {
        setState(() => _selected = sq);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () {
              _game.undo();
              if (_history.isNotEmpty) _history.removeLast();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _game.reset();
              _history.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Turn: ${_game.turn == chess_lib.Color.WHITE ? "White" : "Black"} • ${_history.length} moves'),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                itemCount: 64,
                itemBuilder: (context, i) {
                  final file = i % 8;
                  final rank = 7 - (i ~/ 8);
                  final sq = '${String.fromCharCode(97 + file)}${rank + 1}';
                  final piece = _game.get(sq);
                  final isLight = (file + rank) % 2 == 0;
                  final selected = _selected == sq;
                  return InkWell(
                    onTap: () => _onSquare(sq),
                    child: Container(
                      color: selected ? Colors.yellow.shade700 : (isLight ? Colors.grey.shade300 : Colors.grey.shade700),
                      child: Center(
                        child: Text(
                          _symbol(piece),
                          style: TextStyle(
                            fontSize: 28,
                            color: piece?.color == chess_lib.Color.WHITE ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(_history.isEmpty ? 'No moves yet' : _history.join(' '), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
