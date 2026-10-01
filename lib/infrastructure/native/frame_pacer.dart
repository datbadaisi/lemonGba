import 'dart:math' as math;

/// Fixed-step scheduler for the Game Boy Advance's hardware refresh rate.
///
/// [speed] scales how many emulated frames are consumed per wall-clock tick
/// (1.0 = real-time, 2.0 ≈ double-speed).
class FramePacer {
  FramePacer({this.maxCatchUpFrames = 2});

  static const double gbaFramesPerSecond = 59.727500569606;
  static final Duration framePeriod = Duration(
    microseconds: (Duration.microsecondsPerSecond / gbaFramesPerSecond).round(),
  );

  /// Max emulated frames at 1× after a hitch; scales with [speed].
  final int maxCatchUpFrames;

  double _speed = 1.0;
  Duration? _previous;
  Duration _accumulator = Duration.zero;

  double get speed => _speed;

  set speed(double value) {
    // Keep a sane band even if a caller passes a raw slider value.
    final next = value.clamp(0.25, 8.0);
    if (next == _speed) return;
    _speed = next;
  }

  void reset() {
    _previous = null;
    _accumulator = Duration.zero;
  }

  int consume(Duration now) {
    final previous = _previous;
    _previous = now;
    if (previous == null) return 1;

    var elapsed = now - previous;
    if (elapsed.isNegative) elapsed = Duration.zero;

    // Speed multiplies wall time so 2× advances two GBA frames per real frame.
    final scaledMicros = (elapsed.inMicroseconds * _speed).round();
    var scaled = Duration(microseconds: scaledMicros);

    final maxFrames = math.max(1, (maxCatchUpFrames * _speed).ceil());
    final maxScaled = framePeriod * maxFrames;
    if (scaled > maxScaled) scaled = maxScaled;

    _accumulator += scaled;
    var frames = 0;
    while (_accumulator >= framePeriod && frames < maxFrames) {
      _accumulator -= framePeriod;
      frames++;
    }
    return frames;
  }
}
