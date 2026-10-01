import 'package:flutter/material.dart';

import '../theme/home_tokens.dart';

/// Shared home-shelf geometry (filled shelf and empty state must match).
class HomeShelfMetrics {
  const HomeShelfMetrics({
    required this.tileSize,
    required this.rowHeight,
    required this.contentHeight,
    required this.shelfTop,
    required this.spaceBelow,
  });

  /// Same vertical placement for filled shelf and empty state.
  static const Alignment shelfAlign = Alignment(0, -0.15);

  final double tileSize;

  /// Game row only (tile + title block), without the play-time badge strip.
  final double rowHeight;

  /// Filled shelf column: [rowHeight] + [HomeSizes.playTimeBadgeSlot].
  final double contentHeight;

  final double shelfTop;
  final double spaceBelow;

  static HomeShelfMetrics resolve(double maxHeight) {
    // Reserve the always-present badge strip so tile sizing / centering match
    // the filled [Column] (GameRow + playTimeBadgeSlot).
    final usableH =
        (maxHeight - HomeSizes.playTimeBadgeSlot).clamp(1.0, maxHeight);
    final tileSize = (usableH * HomeSizes.continueTileOfH).clamp(
      HomeSizes.continueTileMinH,
      HomeSizes.continueTileMaxH,
    );
    final rowHeight = tileSize + HomeSizes.tileTitleBlock;
    final contentHeight = rowHeight + HomeSizes.playTimeBadgeSlot;

    // Align(0, -0.15) places the child's center at:
    //   h/2 + y * (h/2)  →  here y = -0.15
    final shelfCenterY = maxHeight * 0.5 * (1 + shelfAlign.y);
    final maxTop = (maxHeight - contentHeight).clamp(0.0, maxHeight);
    final shelfTop =
        (shelfCenterY - contentHeight / 2).clamp(0.0, maxTop);
    final shelfBottom = shelfTop + contentHeight;
    final spaceBelow = (maxHeight - shelfBottom).clamp(0.0, maxHeight);

    return HomeShelfMetrics(
      tileSize: tileSize,
      rowHeight: rowHeight,
      contentHeight: contentHeight,
      shelfTop: shelfTop,
      spaceBelow: spaceBelow,
    );
  }
}
