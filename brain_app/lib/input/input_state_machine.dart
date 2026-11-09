/// Centralized input state machine for single Bluetooth HID button.
///
/// Modes:
/// - NORMAL_NAVIGATION: short=next, double=select, 2s=exit
/// - MORSE_WRITING: presses reserved for Morse, 2s=exit (no Morse char)
/// - VOICE_INPUT: button controls voice (push-to-talk)
/// - FUTURE_INPUT_MODES: extensible
///
/// Each mode owns its interpretation. No button event is processed
/// by both systems. Very-long-press (2s) exit has priority in every
/// mode but never generates a Morse character.
///
/// Timing thresholds are configurable. Double-press detection does
/// not execute short-press first (waits for double-press window).
library;

import 'dart:async';
import 'input_event.dart';

enum InputMode {
  normalNavigation,
  morseWriting,
  voiceInput,
  futureInputModes,
}

class InputTimingConfig {
  final Duration shortPressMax; // < this = short
  final Duration doublePressWindow; // max gap between presses for double
  final Duration veryLongPress; // >= this = exit (2s default)
  final Duration debounce; // ignore bounces < this

  const InputTimingConfig({
    this.shortPressMax = const Duration(milliseconds: 400),
    this.doublePressWindow = const Duration(milliseconds: 350),
    this.veryLongPress = const Duration(seconds: 2),
    this.debounce = const Duration(milliseconds: 50),
  });

  static const InputTimingConfig defaults = InputTimingConfig();
}

class ButtonPressEvent {
  final DateTime pressTime;
  final DateTime releaseTime;
  Duration get duration => releaseTime.difference(pressTime);

  const ButtonPressEvent({required this.pressTime, required this.releaseTime});
}

class InputStateMachine {
  InputMode _mode = InputMode.normalNavigation;
  InputTimingConfig _timing = InputTimingConfig.defaults;
  final StreamController<InputEvent> _controller = StreamController<InputEvent>.broadcast();

  // For double-press detection (normal mode)
  DateTime? _lastPressRelease;
  Timer? _doublePressTimer;
  bool _pendingSinglePress = false;

  // For very-long-press detection (all modes)
  Timer? _veryLongTimer;
  bool _veryLongTriggered = false;

  // For Morse mode: preserve timing
  final List<ButtonPressEvent> _morsePresses = [];

  // Previous screen/position preservation
  String? _savedScreen;
  int _savedPosition = 0;

  InputMode get mode => _mode;
  Stream<InputEvent> get events => _controller.stream;
  List<ButtonPressEvent> get morsePresses => List.unmodifiable(_morsePresses);

  void setTiming(InputTimingConfig config) => _timing = config;

  void setMode(InputMode mode, {String? saveScreen, int savePosition = 0}) {
    _mode = mode;
    if (saveScreen != null) {
      _savedScreen = saveScreen;
      _savedPosition = savePosition;
    }
    // Clear pending state on mode switch (no cross-mode leakage)
    _doublePressTimer?.cancel();
    _pendingSinglePress = false;
    _veryLongTimer?.cancel();
    _veryLongTriggered = false;
  }

  String? get savedScreen => _savedScreen;
  int get savedPosition => _savedPosition;

  /// Call on button press (down).
  void onButtonDown() {
    _veryLongTriggered = false;
    // Start very-long-press timer (2s) — priority in every mode
    _veryLongTimer?.cancel();
    _veryLongTimer = Timer(_timing.veryLongPress, () {
      _veryLongTriggered = true;
      // Exit action — never generates Morse char
      if (_mode == InputMode.morseWriting) {
        // Exit Morse mode, restore previous screen
        _controller.add(InputEventFactory.hardware(InputAction.back, code: 'morse_exit'));
        setMode(InputMode.normalNavigation);
      } else {
        _controller.add(InputEventFactory.hardware(InputAction.back, code: 'very_long_exit'));
      }
    });
  }

  /// Call on button release (up).
  void onButtonUp() {
    _veryLongTimer?.cancel();
    if (_veryLongTriggered) {
      // Already handled as exit — do not generate Morse or navigation
      return;
    }

    final now = DateTime.now();
    // Note: caller should provide actual press duration via onButtonUpWithDuration
    // This method is for simple press/release without duration tracking.
    _handleRelease(now, const Duration(milliseconds: 100));
  }

  /// Call on button release with actual press duration.
  /// Preferred API — preserves timing for Morse decoding.
  void onButtonUpWithDuration(Duration pressDuration) {
    _veryLongTimer?.cancel();
    if (_veryLongTriggered) return;

    final now = DateTime.now();
    _handleRelease(now, pressDuration);
  }

  void _handleRelease(DateTime now, Duration pressDuration) {
    switch (_mode) {
      case InputMode.normalNavigation:
        _handleNavigationRelease(now, pressDuration);
        break;
      case InputMode.morseWriting:
        _handleMorseRelease(now, pressDuration);
        break;
      case InputMode.voiceInput:
        _handleVoiceRelease(now, pressDuration);
        break;
      case InputMode.futureInputModes:
        _controller.add(InputEventFactory.hardware(InputAction.custom, code: 'future'));
        break;
    }
  }

  void _handleNavigationRelease(DateTime now, Duration pressDuration) {
    // Very-long already handled by timer. Ordinary long press (>= shortMax but < veryLong)
    // must NOT trigger selection/navigation/exit — ignore.
    if (pressDuration >= _timing.veryLongPress) return;
    if (pressDuration >= _timing.shortPressMax) {
      // Ordinary long press — ignore (no action)
      return;
    }

    // Short press: check for double-press
    if (_lastPressRelease != null &&
        now.difference(_lastPressRelease!) <= _timing.doublePressWindow) {
      // Double press — cancel pending single, emit select
      _doublePressTimer?.cancel();
      _pendingSinglePress = false;
      _lastPressRelease = null;
      _controller.add(InputEventFactory.hardware(InputAction.confirm, code: 'double_press'));
    } else {
      // Single press — wait for double-press window before emitting next
      // (prevents accidental execution of short-press before double is detected)
      _pendingSinglePress = true;
      _lastPressRelease = now;
      _doublePressTimer?.cancel();
      _doublePressTimer = Timer(_timing.doublePressWindow, () {
        if (_pendingSinglePress) {
          _pendingSinglePress = false;
          _controller.add(InputEventFactory.hardware(InputAction.down, code: 'short_press_next'));
        }
      });
    }
  }

  void _handleMorseRelease(DateTime now, Duration pressDuration) {
    // Morse mode: preserve timing, do not interpret as navigation.
    // Very-long already handled (exit, no Morse char).
    if (pressDuration >= _timing.veryLongPress) return;

    // Record press for Morse decoder (dot/dash based on duration)
    // Dot: < 200ms, Dash: >= 200ms (configurable in decoder)
    _morsePresses.add(ButtonPressEvent(
      pressTime: now.subtract(pressDuration),
      releaseTime: now,
    ));
    // Emit raw Morse event (decoder interprets dot/dash)
    final isDash = pressDuration >= const Duration(milliseconds: 200);
    _controller.add(InputEventFactory.hardware(
      InputAction.custom,
      code: isDash ? 'morse_dash' : 'morse_dot',
    ));
  }

  void _handleVoiceRelease(DateTime now, Duration pressDuration) {
    if (pressDuration >= _timing.veryLongPress) return;
    if (pressDuration >= _timing.shortPressMax) return;
    // Voice mode: short = push-to-talk toggle
    _controller.add(InputEventFactory.hardware(InputAction.voiceStart, code: 'voice_toggle'));
  }

  /// Clear Morse buffer (after decoding a character).
  void clearMorseBuffer() => _morsePresses.clear();

  void dispose() {
    _doublePressTimer?.cancel();
    _veryLongTimer?.cancel();
    _controller.close();
  }
}
