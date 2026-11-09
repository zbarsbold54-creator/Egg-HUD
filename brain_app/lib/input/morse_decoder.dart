/// Morse code decoder for Morse writing mode.
///
/// Receives raw press timing from [InputStateMachine] (dot/dash events)
/// and decodes to characters. Timing thresholds are configurable.
/// Very-long-press (2s) exits Morse mode and never generates a character
/// (handled by state machine before Morse events are emitted).
library;

class MorseDecoder {
  final Duration dotDashThreshold;
  final Duration letterGap;
  final Duration wordGap;

  const MorseDecoder({
    this.dotDashThreshold = const Duration(milliseconds: 200),
    this.letterGap = const Duration(milliseconds: 500),
    this.wordGap = const Duration(milliseconds: 1000),
  });

  static const Map<String, String> _code = {
    '.-': 'A', '-...': 'B', '-.-.': 'C', '-..': 'D', '.': 'E',
    '..-.': 'F', '--.': 'G', '....': 'H', '..': 'I', '.---': 'J',
    '-.-': 'K', '.-..': 'L', '--': 'M', '-.': 'N', '---': 'O',
    '.--.': 'P', '--.-': 'Q', '.-.': 'R', '...': 'S', '-': 'T',
    '..-': 'U', '...-': 'V', '.--': 'W', '-..-': 'X', '-.--': 'Y',
    '--..': 'Z', '-----': '0', '.----': '1', '..---': '2', '...--': '3',
    '....-': '4', '.....': '5', '-....': '6', '--...': '7', '---..': '8',
    '----.': '9', '.-.-.-': '.', '--..--': ',', '..--..': '?',
  };

  /// Decode a Morse code string (e.g. ".-") to a character.
  /// Returns '?' for unknown codes.
  String decode(String morse) => _code[morse] ?? '?';

  /// Encode a character to Morse code.
  String encode(String char) {
    final upper = char.toUpperCase();
    for (final entry in _code.entries) {
      if (entry.value == upper) return entry.key;
    }
    return '';
  }

  /// Convert press durations to Morse symbols.
  /// Dot: < dotDashThreshold, Dash: >= dotDashThreshold.
  String durationsToMorse(List<Duration> presses) {
    return presses.map((d) => d >= dotDashThreshold ? '-' : '.').join();
  }
}
