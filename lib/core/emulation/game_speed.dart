/// Discrete emulation speed steps shared by the pause menu and in-play HUD.
abstract final class GameSpeed {
  /// Ordered notches from normal (1×) to turbo. No slow-mo below 1×.
  static const List<double> steps = [1.0, 1.5, 2.0, 3.0, 4.0];

  static const double normal = 1.0;

  static int indexOf(double speed) {
    var best = 0;
    var bestDist = (steps[0] - speed).abs();
    for (var i = 1; i < steps.length; i++) {
      final d = (steps[i] - speed).abs();
      if (d < bestDist) {
        best = i;
        bestDist = d;
      }
    }
    return best;
  }

  static double snap(double speed) => steps[indexOf(speed)];

  /// [delta] > 0 faster, < 0 slower. Clamped to [steps] ends.
  static double nudge(double speed, int delta) {
    final i = (indexOf(speed) + delta).clamp(0, steps.length - 1);
    return steps[i];
  }

  /// Advance one notch and wrap (1× → 1.5× → … → 4× → 1×).
  static double cycle(double speed, [int delta = 1]) {
    final n = steps.length;
    final i = (indexOf(speed) + delta) % n;
    return steps[i < 0 ? i + n : i];
  }

  static bool canNudge(double speed, int delta) {
    final i = indexOf(speed) + delta;
    return i >= 0 && i < steps.length;
  }

  /// Display label, e.g. `1×`, `1.5×`, `2×`.
  static String label(double speed) {
    final s = snap(speed);
    if (s == s.roundToDouble()) {
      return '${s.toInt()}×';
    }
    // Drop trailing zeros: 1.5 → "1.5×"
    final t = s.toStringAsFixed(2);
    final trimmed = t
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$trimmed×';
  }
}
