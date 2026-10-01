import 'dart:async';

import 'package:flutter/services.dart';

/// App-shell chiptune / UI SFX via a **continuous native AudioTrack mixer**.
///
/// Completely separate from mGBA AAudio game audio.
///
/// Native design (see `GbaSfxHost`):
/// - One MODE_STREAM track keeps writing silence while the activity is visible
///   so the HAL never cold-starts after touch-boost idle (quiet first tap).
/// - [playTap] / [playDock] only arm a monophonic sample cursor — O(1), no
///   SoundPool, no stop/reload, no stream stack.
/// - Stream pauses in [onPause] and while game AAudio is running.
///
/// When the next step suspends the mixer (resume mGBA AAudio, exit play, etc.),
/// await [waitTapSettle] (or use [playTapSettled]) so the sample is not cut off.
class AppSfx {
  AppSfx._();

  static const MethodChannel _channel = MethodChannel('gba_emulator/sfx');

  /// Hold-off after a tap so the monophonic voice can leave the mixer before
  /// the next action stops the stream (AAudio start, route tear-down, …).
  ///
  /// Longer than [PlayModal.sheetExitDuration] on purpose: sheet can finish
  /// closing while SFX still settles before mGBA AAudio resumes.
  static const Duration tapSettle = Duration(milliseconds: 400);

  static Future<void>? _preloadFuture;
  static DateTime? _lastTapAt;

  /// Ensures samples exist and the mixer stream is running.
  static Future<void> preload() {
    return _preloadFuture ??= _doPreload();
  }

  static Future<void> _doPreload() async {
    try {
      await _channel.invokeMethod<bool>('preload');
    } catch (_) {
      _preloadFuture = null;
    }
  }

  /// No-op-ish: asks native to keep the continuous stream up.
  static Future<void> warm() async {
    try {
      await _channel.invokeMethod<void>('warm');
    } catch (_) {}
  }

  static void playDock() => _fire('playDock');

  /// Fire-and-forget tap. Safe for in-sheet navigation while SFX stays active.
  static void playTap() {
    _lastTapAt = DateTime.now();
    _fire('playTap');
  }

  /// Remaining time of [tapSettle] since the last [playTap], if any.
  ///
  /// Use before resuming mGBA AAudio (or any action that calls
  /// `GbaSfxHost.setSuspended(true)`) so a just-fired tap is not silenced.
  /// No-ops when no recent tap or when [tapSettle] has already elapsed
  /// (e.g. sheet close animation already ate the budget).
  static Future<void> waitTapSettle() async {
    final t = _lastTapAt;
    if (t == null) return;
    final left = tapSettle - DateTime.now().difference(t);
    if (left <= Duration.zero) return;
    await Future<void>.delayed(left);
  }

  /// Play tap and wait the full [tapSettle] (when the follow-up is immediate).
  static Future<void> playTapSettled() async {
    playTap();
    await Future<void>.delayed(tapSettle);
  }

  /// Fire-and-forget — never await on the UI isolate.
  static void _fire(String method) {
    try {
      unawaited(_channel.invokeMethod<void>(method).catchError((_) {}));
    } catch (_) {}
  }

  static Future<void> dispose() async {
    _preloadFuture = null;
  }
}

/// Back-compat alias for lemon loading dock.
class DockChiptune {
  DockChiptune._();

  static Future<void> preload() => AppSfx.preload();

  static Future<void> play() async => AppSfx.playDock();

  static Future<void> dispose() => AppSfx.dispose();
}
