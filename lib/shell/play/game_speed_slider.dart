import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/emulation/game_speed.dart';
import '../theme/play_tokens.dart';

/// Discrete speed control shared by the pause menu page and the in-play HUD.
class GameSpeedSlider extends StatelessWidget {
  const GameSpeedSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final double value;
  final ValueChanged<double> onChanged;

  /// Single-row layout for the top-band snackbar (must stay short).
  final bool compact;

  void _onSlide(double v) {
    final next = GameSpeed.steps[v.round()];
    if (next != GameSpeed.snap(value)) onChanged(next);
  }

  SliderThemeData _theme(
    BuildContext context, {
    required double thumbRadius,
    required double overlayRadius,
  }) {
    return SliderTheme.of(context).copyWith(
      trackHeight: PlayModal.speedSliderTrackH,
      activeTrackColor: PlayColors.success.withValues(alpha: 0.85),
      inactiveTrackColor: PlayModal.border,
      thumbColor: PlayColors.success,
      overlayColor: PlayColors.success.withValues(alpha: 0.16),
      thumbShape: RoundSliderThumbShape(
        enabledThumbRadius: thumbRadius,
        elevation: 0,
        pressedElevation: 0,
      ),
      overlayShape: RoundSliderOverlayShape(overlayRadius: overlayRadius),
      trackShape: const RoundedRectSliderTrackShape(),
      tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.5),
      activeTickMarkColor: PlayModal.surface,
      inactiveTickMarkColor: PlayModal.chevron,
      showValueIndicator: ShowValueIndicator.never,
      // Kill Material's default vertical padding that forces ~48px height.
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = GameSpeed.indexOf(value).toDouble();
    final max = (GameSpeed.steps.length - 1).toDouble();

    if (compact) {
      // One row: label · slider · value — fits the top black band.
      return Row(
        children: [
          Text(
            'Speed',
            style: TextStyle(
              color: PlayModal.slotMeta,
              fontSize: PlayModal.speedLabelSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: PlaySpacing.sm),
          Expanded(
            child: SizedBox(
              height: PlayModal.speedHudSliderH,
              child: SliderTheme(
                data: _theme(
                  context,
                  thumbRadius: PlayModal.speedHudThumb / 2,
                  overlayRadius: PlayModal.speedHudThumb,
                ),
                child: Slider(
                  value: index,
                  min: 0,
                  max: max,
                  divisions: GameSpeed.steps.length - 1,
                  onChanged: _onSlide,
                ),
              ),
            ),
          ),
          const SizedBox(width: PlaySpacing.sm),
          Text(
            GameSpeed.label(value),
            style: const TextStyle(
              color: PlayColors.success,
              fontSize: PlayModal.speedValueSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Game speed',
              style: TextStyle(
                color: PlayModal.slotMeta,
                fontSize: PlayModal.slotLabelSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              GameSpeed.label(value),
              style: const TextStyle(
                color: PlayColors.success,
                fontSize: PlayModal.tileTitleSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: PlaySpacing.sm),
        SliderTheme(
          data: _theme(
            context,
            thumbRadius: PlayModal.speedSliderThumb / 2,
            overlayRadius: PlayModal.speedSliderThumb,
          ),
          child: Slider(
            value: index,
            min: 0,
            max: max,
            divisions: GameSpeed.steps.length - 1,
            onChanged: _onSlide,
          ),
        ),
        const SizedBox(height: PlaySpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final step in GameSpeed.steps)
              Text(
                GameSpeed.label(step),
                style: TextStyle(
                  color: GameSpeed.indexOf(value) == GameSpeed.indexOf(step)
                      ? PlayColors.success
                      : PlayModal.slotMetaEmpty,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Compact toast-style speed chip (speed-button long-press or drag).
///
/// Placement mirrors [AppToast]: free-floating under the status bar.
class GameSpeedHudChip extends StatelessWidget {
  const GameSpeedHudChip({
    super.key,
    required this.value,
    required this.onChanged,
    required this.visible,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final maxW = math.min(
      PlayModal.speedHudMaxWidth,
      MediaQuery.sizeOf(context).width - PlayModal.screenMargin * 2,
    );

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: PlayModal.speedHudEnterDuration,
        curve: PlayModal.speedHudEnterCurve,
        child: AnimatedSlide(
          // Same enter motion as [AppToast]: drop down a few px + fade.
          offset: visible ? Offset.zero : const Offset(0, -0.4),
          duration: PlayModal.speedHudEnterDuration,
          curve: PlayModal.speedHudEnterCurve,
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: DecoratedBox(
                decoration: PlayModal.toastDecoration().copyWith(
                  borderRadius:
                      BorderRadius.circular(PlayModal.speedHudRadius),
                ),
                child: Padding(
                  padding: PlayModal.speedHudPadding,
                  child: GameSpeedSlider(
                    value: value,
                    onChanged: onChanged,
                    compact: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
