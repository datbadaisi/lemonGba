import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'dock_chiptune.dart' show AppSfx;

/// Timing for the dock → content handoff (parent fades this overlay out).
abstract final class LemonBootMotion {
  /// Full-screen dissolve of the dock overlay after [LemonLoadingScreen.onFinished].
  static const Duration handoffFade = Duration(milliseconds: 560);
  static const Curve handoffCurve = Curves.easeInOutCubic;
}

/// Flat loading screen: **lemon** and **Gba** approach once and meet.
///
/// No loop — one dock, one chiptune hit, then hold until [isReady] and
/// [onFinished]. Parent should crossfade this away with [LemonBootMotion].
class LemonLoadingScreen extends StatefulWidget {
  const LemonLoadingScreen({
    super.key,
    this.message = 'Loading…',
    this.showBrand = true,
    this.isReady = false,
    this.onFinished,
  });

  final String message;

  /// Kept for call-site compatibility; brand is the two word clusters.
  final bool showBrand;

  /// Parent sets this when work is done. Screen still waits for dock + hold.
  final bool isReady;

  /// Called once after dock (and short hold) completes while ready.
  /// Prefer fading the overlay out after this rather than swapping instantly.
  final VoidCallback? onFinished;

  @override
  State<LemonLoadingScreen> createState() => _LemonLoadingScreenState();
}

class _LemonLoadingScreenState extends State<LemonLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _approach;

  double _gap = _maxGap;
  double _contact = 0;
  bool _docked = false;
  bool _sfxPlayed = false;
  bool _didFinish = false;
  bool _finishScheduled = false;

  static const _maxGap = 72.0;
  static const _approachDuration = Duration(milliseconds: 900);
  static const _holdAfterReady = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    // Real SoundPool preload (started at engine attach; await coalesces).
    unawaited(AppSfx.preload());

    _approach = AnimationController(vsync: this, duration: _approachDuration)
      ..addListener(_onApproachTick)
      ..addStatusListener(_onApproachStatus);

    _approach.forward(from: 0);

    if (widget.isReady) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryFinish();
      });
    }
  }

  @override
  void didUpdateWidget(covariant LemonLoadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReady && !oldWidget.isReady) {
      _tryFinish();
    }
  }

  @override
  void dispose() {
    _approach
      ..removeListener(_onApproachTick)
      ..removeStatusListener(_onApproachStatus)
      ..dispose();
    super.dispose();
  }

  void _onApproachTick() {
    final t = Curves.easeOutCubic.transform(_approach.value);
    final gap = _maxGap * (1 - t);
    final contact = Curves.easeOut.transform(t);
    final justDocked = !_docked && gap <= 0.5;

    setState(() {
      _gap = gap;
      _contact = contact;
      if (gap <= 0.5) _docked = true;
    });

    if (justDocked) {
      _playDockSfxOnce();
      _tryFinish();
    }
  }

  void _onApproachStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final wasDocked = _docked;
    setState(() {
      _gap = 0;
      _contact = 1;
      _docked = true;
    });
    if (!wasDocked) {
      _playDockSfxOnce();
    }
    _tryFinish();
  }

  void _playDockSfxOnce() {
    if (_sfxPlayed) return;
    _sfxPlayed = true;
    // Ensure mixer stream is up before arming the voice (cold first open).
    unawaited(() async {
      await AppSfx.preload();
      AppSfx.warm();
      AppSfx.playDock();
    }());
  }

  void _tryFinish() {
    if (_didFinish || _finishScheduled) return;
    if (!widget.isReady || !_docked) return;

    _finishScheduled = true;
    Future<void>.delayed(_holdAfterReady, () {
      if (!mounted || _didFinish) return;
      _didFinish = true;
      widget.onFinished?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LemonBrand.bg,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BrandWordDock(gap: _gap, contact: _contact),
              const SizedBox(height: 28),
              Text(
                widget.message,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                  color: LemonBrand.cream.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two word clusters: `lemon` ←gap→ `Gba`. gap==0 means they sit as one word.
class _BrandWordDock extends StatelessWidget {
  const _BrandWordDock({required this.gap, required this.contact});

  final double gap;
  final double contact;

  static const _baseStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -0.6,
  );

  @override
  Widget build(BuildContext context) {
    final tracking = _lerp(-0.6, -1.2, contact);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Transform.translate(
          offset: Offset(-gap / 2, 0),
          child: Text(
            'lemon',
            style: _baseStyle.copyWith(
              color: LemonBrand.lemon,
              letterSpacing: tracking,
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(gap / 2, 0),
          child: Text(
            'Gba',
            style: _baseStyle.copyWith(
              color: Color.lerp(
                LemonBrand.cream.withValues(alpha: 0.72),
                LemonBrand.cream,
                contact,
              ),
              fontWeight: FontWeight.w700,
              letterSpacing: tracking,
            ),
          ),
        ),
      ],
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Brand colors — flat palette.
abstract final class LemonBrand {
  static const bg = Color(0xFF000000);
  static const lemon = Color(0xFFFFD93D);
  static const cream = Color(0xFFFFF8E7);
}
