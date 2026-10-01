import 'package:flutter/material.dart';

import '../../../models/play_layout_profile.dart';
import 'play_layout.dart';

/// Shared "scale about a fixed center" math for corner grips and pinch.
///
/// One model, two input adapters — keeps the editor free of parallel resize paths.
@immutable
class LayoutResizeSession {
  const LayoutResizeSession({
    required this.id,
    required this.center,
    required this.stock,
    required this.playSize,
  });

  final PlayElementId id;
  final Offset center;
  final Rect stock;
  final Size playSize;

  /// Start a session from the current resolved layout + draft element.
  factory LayoutResizeSession.begin({
    required PlayElementId id,
    required PlayLayout layout,
  }) {
    return LayoutResizeSession(
      id: id,
      center: layout.rectOf(id).center,
      stock: layout.stockOf(id),
      playSize: Size(layout.width, layout.height),
    );
  }

  /// Scale from finger position relative to [center] (corner drag).
  PlayElementTransform transformForPointer(Offset localPos) {
    final stockCorner = Offset(stock.width / 2, stock.height / 2).distance;
    if (stockCorner < 1) {
      return PlayElementTransform(
        centerX: center.dx / playSize.width,
        centerY: center.dy / playSize.height,
      );
    }
    final dist = (localPos - center).distance;
    final scale = PlayLayout.clampScale(
      id,
      dist / stockCorner,
      stock,
      playSize.width,
      playSize.height,
    );
    return PlayElementTransform(
      centerX: center.dx / playSize.width,
      centerY: center.dy / playSize.height,
      scale: scale,
    );
  }

  /// Scale from a pinch gesture factor (cumulative from gesture start).
  PlayElementTransform transformForPinch({
    required double baseScale,
    required double gestureScale,
  }) {
    final scale = PlayLayout.clampScale(
      id,
      baseScale * gestureScale,
      stock,
      playSize.width,
      playSize.height,
    );
    return PlayElementTransform(
      centerX: center.dx / playSize.width,
      centerY: center.dy / playSize.height,
      scale: scale,
    );
  }

  double clampedScale(double raw) => PlayLayout.clampScale(
        id,
        raw,
        stock,
        playSize.width,
        playSize.height,
      );
}

/// Per-element resize affordances (table, not scatter flags).
enum ElementResizeMode {
  /// Corner grips only (virtual pad controls).
  corners,

  /// Corner grips + pinch (game frame).
  cornersAndPinch,
}

extension PlayElementResizePolicy on PlayElementId {
  ElementResizeMode get resizeMode => switch (this) {
        PlayElementId.game => ElementResizeMode.cornersAndPinch,
        _ => ElementResizeMode.corners,
      };

  bool get allowsPinch => resizeMode == ElementResizeMode.cornersAndPinch;
  bool get allowsCorners => true;
}
