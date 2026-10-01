import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/play_tokens.dart';

/// App-wide top toast (slide down from top). Prefer this over inline status
/// text or Material [SnackBar] (SnackBar paints a dark elevation slab).
abstract final class AppToast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  static void show(
    BuildContext context, {
    required String message,
    bool isSuccess = true,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Result toasts supersede any in-flight progress chip.
    AppProgressToast.dismiss();
    dismiss();

    final accent = isSuccess ? PlayColors.success : PlayColors.danger;

    _entry = OverlayEntry(
      builder: (ctx) {
        final top = MediaQuery.paddingOf(ctx).top + PlayModal.screenMargin;
        return Positioned(
          top: top,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.min(
                    PlayModal.toastMaxWidth,
                    MediaQuery.sizeOf(ctx).width - PlayModal.screenMargin * 2,
                  ),
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: PlayModal.toastEnterDuration,
                  curve: PlayModal.toastEnterCurve,
                  builder: (context, t, child) {
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, -PlayModal.toastSlide * (1 - t)),
                        child: child,
                      ),
                    );
                  },
                  child: Material(
                    color: Colors.transparent,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    child: DecoratedBox(
                      decoration: PlayModal.toastDecoration(),
                      child: Padding(
                        padding: PlayModal.toastPadding,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: isSuccess
                                  ? HugeIcons.strokeRoundedCheckmarkCircle01
                                  : HugeIcons.strokeRoundedCancelCircle,
                              color: accent,
                              size: PlayModal.headerIcon,
                            ),
                            const SizedBox(width: PlaySpacing.md),
                            Flexible(
                              child: Text(
                                message,
                                softWrap: true,
                                style: const TextStyle(
                                  inherit: false,
                                  color: PlayModal.onSurface,
                                  fontSize: PlayModal.slotLabelSize,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);
    _timer = Timer(PlayModal.toastDuration, dismiss);
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, isSuccess: true);

  static void error(BuildContext context, String message) =>
      show(context, message: message, isSuccess: false);
}

/// Compact top progress chip for pack export / save-import.
///
/// Same placement + chrome as the in-play **speed HUD**: short label, then a
/// fully rounded track (success green on border grey). No spinner icon.
abstract final class AppProgressToast {
  static OverlayEntry? _entry;
  static final ValueNotifier<_ProgressChipState> _state =
      ValueNotifier(const _ProgressChipState(label: ''));

  static bool get isShowing => _entry != null;

  static void dismiss() {
    _entry?.remove();
    _entry = null;
    _state.value = const _ProgressChipState(label: '');
  }

  /// Show (or refresh) the progress chip. [message] is the leading label.
  static void show(BuildContext context, {String message = 'Working…'}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    AppToast.dismiss();
    final label = _shortLabel(message);
    _state.value = _ProgressChipState(label: label, progress: null);

    if (_entry != null) return;

    _entry = OverlayEntry(
      builder: (ctx) {
        final top = MediaQuery.paddingOf(ctx).top + PlayModal.screenMargin;
        final maxW = math.min(
          PlayModal.speedHudMaxWidth,
          MediaQuery.sizeOf(ctx).width - PlayModal.screenMargin * 2,
        );
        // Fully rounded capsule (both ends).
        const pillR = 99.0;
        return Positioned(
          top: top,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: PlayModal.speedHudEnterDuration,
                  curve: PlayModal.speedHudEnterCurve,
                  builder: (context, t, child) {
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, -PlayModal.speedHudSlide * (1 - t)),
                        child: child,
                      ),
                    );
                  },
                  child: Material(
                    color: Colors.transparent,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    child: DecoratedBox(
                      decoration: PlayModal.toastDecoration().copyWith(
                        borderRadius: BorderRadius.circular(pillR),
                      ),
                      child: Padding(
                        // Same band height language as [GameSpeedHudChip].
                        padding: PlayModal.speedHudPadding,
                        child: SizedBox(
                          height: PlayModal.speedHudSliderH,
                          child: ValueListenableBuilder<_ProgressChipState>(
                            valueListenable: _state,
                            builder: (context, s, _) {
                              return Row(
                                children: [
                                  Text(
                                    s.label,
                                    style: const TextStyle(
                                      inherit: false,
                                      color: PlayModal.slotMeta,
                                      fontSize: PlayModal.speedLabelSize,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(width: PlaySpacing.sm),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(pillR),
                                      child: LinearProgressIndicator(
                                        // Material Slider track paints a bit
                                        // heavier than minHeight=3; match that.
                                        minHeight:
                                            PlayModal.speedSliderTrackH + 2,
                                        value: s.progress,
                                        backgroundColor: PlayModal.border,
                                        color: PlayColors.success
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);
  }

  /// Optional determinate update (0–1). Null keeps indeterminate.
  static void update(String message, {double? progress}) {
    if (_entry == null) return;
    _state.value = _ProgressChipState(
      label: _shortLabel(message),
      progress: progress,
    );
  }

  /// Short leading label so the chip stays HUD-sized (like “Speed”).
  static String _shortLabel(String message) {
    final t = message.trim();
    if (t.isEmpty) return 'Working';
    final lower = t.toLowerCase();
    if (lower.contains('export')) return 'Exporting';
    if (lower.contains('restor') || lower.contains('import')) return 'Importing';
    if (lower.contains('sav')) return 'Saving';
    // Strip trailing ellipsis / punctuation for a compact word.
    return t
        .replaceAll(RegExp(r'[.…]+$'), '')
        .split(RegExp(r'\s+'))
        .first;
  }

  static void completeSuccess(BuildContext context, String message) {
    dismiss();
    if (context.mounted) AppToast.success(context, message);
  }

  static void completeError(BuildContext context, String message) {
    dismiss();
    if (context.mounted) AppToast.error(context, message);
  }
}

class _ProgressChipState {
  const _ProgressChipState({required this.label, this.progress});

  final String label;

  /// `null` = indeterminate.
  final double? progress;
}
