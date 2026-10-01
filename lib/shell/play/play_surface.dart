import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/emulation/emulator_input.dart';
import '../theme/play_tokens.dart';
import 'emulator_renderer.dart';
import 'game_speed_slider.dart';
import 'layout/play_layout.dart';
import 'virtual_pad.dart';

/// Landscape game video and virtual controls. This is shell-only rendering;
/// it receives input and frame presentation ports instead of an emulator.
class PlaySurface extends StatelessWidget {
  const PlaySurface({
    super.key,
    required this.layout,
    required this.renderer,
    required this.onKey,
    required this.onMenu,
    required this.onQuickSave,
    required this.onGameDoubleTap,
    required this.userPaused,
    required this.speed,
    required this.speedHudVisible,
    required this.onSpeedChanged,
    required this.onSpeedCycle,
    required this.onSpeedHudPeek,
  });

  final PlayLayout layout;
  final EmulatorRenderer renderer;
  final KeyHandler onKey;
  final VoidCallback onMenu;
  final VoidCallback onQuickSave;

  /// Double-tap the game frame to pause / resume (not the pad).
  final VoidCallback onGameDoubleTap;

  /// User-initiated pause (double-tap) — show a light overlay on the frame.
  final bool userPaused;

  final double speed;
  final bool speedHudVisible;
  final ValueChanged<double> onSpeedChanged;

  /// Long-press speed button: advance one notch (wraps).
  final VoidCallback onSpeedCycle;

  /// Short tap speed button: show HUD without changing speed.
  final VoidCallback onSpeedHudPeek;

  Widget _pad(Rect rect, Widget child) {
    final o = layout.opacityFor(rect);
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: o < 1.0 ? Opacity(opacity: o, child: child) : child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = layout;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: l.gameRect.left,
          top: l.gameRect.top,
          width: l.gameRect.width,
          height: l.gameRect.height,
          child: Semantics(
            button: true,
            label: userPaused ? 'Resume game' : 'Pause game',
            hint: 'Double tap the game screen to pause or resume',
            // Single activation for screen readers (sighted path is double-tap).
            onTap: onGameDoubleTap,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: onGameDoubleTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  renderer.usesExternalTexture
                      ? ValueListenableBuilder<int?>(
                          valueListenable: renderer.textureId,
                          builder: (_, id, _) => id == null
                              ? const ColoredBox(
                                  color: PlayColors.framePlaceholder,
                                )
                              : Texture(
                                  textureId: id,
                                  filterQuality: FilterQuality.none,
                                ),
                        )
                      : ValueListenableBuilder<ui.Image?>(
                          valueListenable: renderer.frame,
                          builder: (_, image, _) => image == null
                              ? const ColoredBox(
                                  color: PlayColors.framePlaceholder,
                                )
                              : RawImage(
                                  image: image,
                                  width: l.gameWidth,
                                  height: l.gameHeight,
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.none,
                                ),
                        ),
                  // Small pause glyph — top-right of the game frame only.
                  if (userPaused)
                    const Positioned(
                      top: PlaySpacing.sm,
                      right: PlaySpacing.sm,
                      child: IgnorePointer(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedPause,
                          color: PlayColors.pauseIcon,
                          size: PlaySizes.pauseIcon,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Free-floating speed chip — same placement idea as [AppToast]
        // (safe-area top + screen margin), not locked into the black band.
        Positioned(
          top: MediaQuery.paddingOf(context).top + PlayModal.screenMargin,
          left: 0,
          right: 0,
          child: Center(
            child: GameSpeedHudChip(
              value: speed,
              visible: speedHudVisible,
              onChanged: onSpeedChanged,
            ),
          ),
        ),
        _pad(
          l.shoulderLRect,
          VirtualShoulder(
            label: 'L',
            keyId: EmulatorInput.l,
            onKey: onKey,
            width: l.shoulderLRect.width,
            height: l.shoulderLRect.height,
          ),
        ),
        _pad(
          l.shoulderRRect,
          VirtualShoulder(
            label: 'R',
            keyId: EmulatorInput.r,
            onKey: onKey,
            width: l.shoulderRRect.width,
            height: l.shoulderRRect.height,
          ),
        ),
        _pad(
          l.selectRect,
          VirtualMetaButton(
            label: 'SELECT',
            keyId: EmulatorInput.select,
            onKey: onKey,
            width: l.selectRect.width,
            height: l.selectRect.height,
          ),
        ),
        _pad(
          l.startRect,
          VirtualMetaButton(
            label: 'START',
            keyId: EmulatorInput.start,
            onKey: onKey,
            width: l.startRect.width,
            height: l.startRect.height,
          ),
        ),
        _pad(
          l.menuRect,
          VirtualMenuButton(
            onPressed: onMenu,
            onLongPress: onQuickSave,
            size: l.menuSize,
          ),
        ),
        _pad(
          l.speedRect,
          VirtualSpeedButton(
            onLongPress: onSpeedCycle,
            onPressed: onSpeedHudPeek,
            size: l.speedRect.width,
          ),
        ),
        _pad(
          l.dpadRect,
          VirtualDpad(onKey: onKey, size: l.dpadSize),
        ),
        _pad(
          l.faceBRect,
          VirtualFaceButton(
            label: 'B',
            keyId: EmulatorInput.b,
            onKey: onKey,
            size: l.faceBSize,
          ),
        ),
        _pad(
          l.faceARect,
          VirtualFaceButton(
            label: 'A',
            keyId: EmulatorInput.a,
            onKey: onKey,
            size: l.faceASize,
          ),
        ),
      ],
    );
  }
}
