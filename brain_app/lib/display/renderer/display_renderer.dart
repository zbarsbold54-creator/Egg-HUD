/// Central render engine. All screens draw into a shared 128x64 canvas,
/// which is then transformed, encoded, and sent to the HUD Egg.
///
/// Only sends a frame when the canvas actually changed (hash comparison),
/// to avoid burning battery on both ends for no visible change.
library;

import 'dart:async';
import '../framebuffer/framebuffer.dart';
import '../encoders/display_frame_encoder.dart';
import '../transformations/display_transform.dart';

typedef FrameSink = void Function(List<int> frameBytes);

class DisplayRenderer {
  final Framebuffer _canvas = Framebuffer();
  final DisplayFrameEncoder _encoder = DisplayFrameEncoder();
  DisplayTransform _transform = DisplayTransform.identity;
  FrameSink? _sink;

  int _lastHash = 0;
  bool _dirty = true;
  Timer? _keepAliveTimer;
  Duration _keepAliveInterval = const Duration(seconds: 10);
  bool _keepAliveEnabled = false;

  Framebuffer get canvas => _canvas;
  DisplayTransform get transform => _transform;
  bool get keepAliveEnabled => _keepAliveEnabled;
  Duration get keepAliveInterval => _keepAliveInterval;

  void setTransform(DisplayTransform t) {
    _transform = t;
    _dirty = true;
  }

  void setSink(FrameSink? sink) {
    _sink = sink;
  }

  void setKeepAlive({required bool enabled, Duration interval = const Duration(seconds: 10)}) {
    _keepAliveEnabled = enabled;
    _keepAliveInterval = interval;
    _keepAliveTimer?.cancel();
    if (enabled) {
      _keepAliveTimer = Timer.periodic(interval, (_) => _flush(force: true));
    }
  }

  /// Flush if the canvas actually changed (hash comparison).
  /// Call after drawing into [canvas]. Does not force-send unchanged frames.
  void requestFrame() {
    _flush();
  }

  /// Force-send the current canvas (used for keep-alive and tests).
  void forceFrame() {
    _flush(force: true);
  }

  void _flush({bool force = false}) {
    if (_sink == null) return;
    final transformed = _transform.apply(_canvas);
    final h = transformed.hash;
    if (!force && !_dirty && h == _lastHash) return;
    final bytes = _encoder.encode(transformed);
    if (bytes.length != Framebuffer.byteCount) return; // safety
    _sink!(bytes);
    _lastHash = h;
    _dirty = false;
  }

  /// Get the current transformed bytes (for simulator / preview).
  List<int> getCurrentBytes() {
    final transformed = _transform.apply(_canvas);
    return _encoder.encode(transformed);
  }

  void dispose() {
    _keepAliveTimer?.cancel();
  }
}
