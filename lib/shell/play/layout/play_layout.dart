import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/play_layout_profile.dart';
import '../../theme/play_tokens.dart';

/// Resolved play layout for one frame of the landscape play surface.
///
/// Geometry is derived once from constraints + safe-area bottom, then optionally
/// customized via [PlayLayoutProfile]. Tokens stay in [PlaySizes]/[PlaySpacing].
@immutable
class PlayLayout {
  const PlayLayout({
    required this.width,
    required this.height,
    required this.bottomSafe,
    required this.stockRects,
    required this.gameRect,
    required this.dpadRect,
    required this.faceARect,
    required this.faceBRect,
    required this.shoulderLRect,
    required this.shoulderRRect,
    required this.selectRect,
    required this.startRect,
    required this.menuRect,
    required this.speedRect,
  });

  final double width;
  final double height;
  final double bottomSafe;

  /// Untransformed stock geometry for this frame (scale math / editor).
  /// Computed once in [resolve] — do not re-resolve defaults separately.
  final Map<PlayElementId, Rect> stockRects;

  final Rect gameRect;
  final Rect dpadRect;
  final Rect faceARect;
  final Rect faceBRect;
  final Rect shoulderLRect;
  final Rect shoulderRRect;
  final Rect selectRect;
  final Rect startRect;
  final Rect menuRect;
  final Rect speedRect;

  double get gameWidth => gameRect.width;
  double get gameHeight => gameRect.height;
  double get gameLeft => gameRect.left;
  double get gameTop => gameRect.top;
  double get gameBottom => height - gameRect.bottom;

  double get dpadSize => dpadRect.width;
  double get faceASize => faceARect.width;
  double get faceBSize => faceBRect.width;
  double get metaWidth => selectRect.width;
  double get metaHeight => selectRect.height;
  double get shoulderWidth => shoulderLRect.width;
  double get shoulderHeight => shoulderLRect.height;
  double get menuSize => menuRect.width;

  /// GBA native aspect 240:160.
  static const double gameAspect = 240 / 160;

  /// Opacity for a control that may cover the game frame.
  double opacityFor(Rect control) =>
      control.overlaps(gameRect) ? PlaySizes.overlapOpacity : 1.0;

  Rect rectOf(PlayElementId id) => switch (id) {
        PlayElementId.game => gameRect,
        PlayElementId.dpad => dpadRect,
        PlayElementId.faceA => faceARect,
        PlayElementId.faceB => faceBRect,
        PlayElementId.shoulderL => shoulderLRect,
        PlayElementId.shoulderR => shoulderRRect,
        PlayElementId.select => selectRect,
        PlayElementId.start => startRect,
        PlayElementId.menu => menuRect,
        PlayElementId.speed => speedRect,
      };

  /// Stock (pre-profile) rect for [id] from this resolve pass.
  Rect stockOf(PlayElementId id) => stockRects[id]!;

  /// Max scale for [id] given its stock [base] rect and play size.
  ///
  /// Game: scales until it touches play edges (aspect preserved).
  static double maxScaleFor(
    PlayElementId id,
    Rect base,
    double playW,
    double playH,
  ) {
    if (id == PlayElementId.game) {
      if (base.width <= 0 || base.height <= 0) return 1.0;
      final byW = playW / base.width;
      final byH = playH / base.height;
      return math.min(byW, byH).clamp(1.0, id.maxScaleSoft);
    }
    return id.maxScaleSoft;
  }

  static double clampScale(
    PlayElementId id,
    double scale,
    Rect base,
    double playW,
    double playH,
  ) {
    final lo = id.minScale;
    final hi = maxScaleFor(id, base, playW, playH);
    return scale.clamp(lo, hi);
  }

  factory PlayLayout.resolve({
    required double width,
    required double height,
    required double bottomSafe,
    PlayLayoutProfile? profile,
  }) {
    final h = height;
    final w = width;
    final p = profile ?? PlayLayoutProfile.defaults;

    final verticalInset = (h * PlaySizes.gameInsetOfH).clamp(
      PlaySizes.gameInsetMin,
      PlaySizes.gameInsetMax,
    );
    final gameH = (h - verticalInset * 2).clamp(1.0, h);
    final gameW = gameH * gameAspect;
    final gameLeft = (w - gameW) / 2;
    final gameTop = (h - gameH) / 2;

    final dpadSize = h * PlaySizes.dpadOfH;
    final faceSize = h * PlaySizes.faceOfH;
    final metaW = h * PlaySizes.metaWOfH;
    final metaH = h * PlaySizes.metaHOfH;
    final shoulderW = h * PlaySizes.shoulderWOfH;
    final shoulderH = h * PlaySizes.shoulderHOfH;
    final menuSize = (h * PlaySizes.menuOfH).clamp(
      PlaySizes.menuMin,
      PlaySizes.menuMax,
    );

    final gameBottom = gameTop;
    final metaBottom = (gameBottom + h * PlaySizes.metaHangAboveOfH - metaH)
        .clamp(PlaySpacing.xs, h);
    final metaLeft = (gameLeft - metaW - PlaySpacing.gapToFrame).clamp(
      PlaySpacing.edgeMin,
      w - metaW - PlaySpacing.edgeMin,
    );

    final shoulderTop =
        (gameTop + h * PlaySizes.shoulderHangBelowOfH - shoulderH).clamp(
          PlaySpacing.xs,
          h,
        );
    final shoulderLeft = (gameLeft - shoulderW - PlaySpacing.gapToFrame).clamp(
      PlaySpacing.edgeMin,
      w - shoulderW - PlaySpacing.edgeMin,
    );

    final controlEdge = PlaySpacing.edge;
    final faceClusterW = faceSize * PlaySizes.faceClusterScale;
    final faceClusterH = faceClusterW * PlaySizes.faceClusterAspect;

    // Vertical band used by stock D-pad / face Align.centerLeft/Right.
    final padBandH = (h - bottomSafe).clamp(1.0, h);
    final dpadTop = (padBandH - dpadSize) / 2;
    final faceTop = (padBandH - faceClusterH) / 2;
    final faceLeft = w - controlEdge - faceClusterW;

    final baseGame = Rect.fromLTWH(gameLeft, gameTop, gameW, gameH);
    final baseDpad = Rect.fromLTWH(controlEdge, dpadTop, dpadSize, dpadSize);
    // Stock diagonal A (top-right) / B (bottom-left) within the cluster.
    final baseFaceA = Rect.fromLTWH(
      faceLeft + faceClusterW - faceSize,
      faceTop,
      faceSize,
      faceSize,
    );
    final baseFaceB = Rect.fromLTWH(
      faceLeft,
      faceTop + faceClusterH - faceSize,
      faceSize,
      faceSize,
    );
    final baseShoulderL = Rect.fromLTWH(
      shoulderLeft,
      shoulderTop,
      shoulderW,
      shoulderH,
    );
    final baseShoulderR = Rect.fromLTWH(
      w - shoulderLeft - shoulderW,
      shoulderTop,
      shoulderW,
      shoulderH,
    );
    final baseSelect = Rect.fromLTWH(
      metaLeft,
      h - metaBottom - metaH,
      metaW,
      metaH,
    );
    final baseStart = Rect.fromLTWH(
      w - metaLeft - metaW,
      h - metaBottom - metaH,
      metaW,
      metaH,
    );
    final baseMenu = Rect.fromLTWH(
      controlEdge,
      h - metaBottom - menuSize,
      menuSize,
      menuSize,
    );
    final baseSpeed = Rect.fromLTWH(
      w - controlEdge - menuSize,
      h - metaBottom - menuSize,
      menuSize,
      menuSize,
    );

    final stock = <PlayElementId, Rect>{
      PlayElementId.game: baseGame,
      PlayElementId.dpad: baseDpad,
      PlayElementId.faceA: baseFaceA,
      PlayElementId.faceB: baseFaceB,
      PlayElementId.shoulderL: baseShoulderL,
      PlayElementId.shoulderR: baseShoulderR,
      PlayElementId.select: baseSelect,
      PlayElementId.start: baseStart,
      PlayElementId.menu: baseMenu,
      PlayElementId.speed: baseSpeed,
    };

    Rect apply(PlayElementId id) =>
        _applyTransform(stock[id]!, p.of(id), id, w, h);

    return PlayLayout(
      width: w,
      height: h,
      bottomSafe: bottomSafe,
      stockRects: Map.unmodifiable(stock),
      gameRect: apply(PlayElementId.game),
      dpadRect: apply(PlayElementId.dpad),
      faceARect: apply(PlayElementId.faceA),
      faceBRect: apply(PlayElementId.faceB),
      shoulderLRect: apply(PlayElementId.shoulderL),
      shoulderRRect: apply(PlayElementId.shoulderR),
      selectRect: apply(PlayElementId.select),
      startRect: apply(PlayElementId.start),
      menuRect: apply(PlayElementId.menu),
      speedRect: apply(PlayElementId.speed),
    );
  }

  /// Scale + optional center from [transform], clamped on-screen.
  static Rect _applyTransform(
    Rect base,
    PlayElementTransform transform,
    PlayElementId id,
    double playW,
    double playH,
  ) {
    if (transform.isDefault) return base;

    final raw = transform.scale ?? 1.0;
    final s = clampScale(id, raw, base, playW, playH);
    final newW = base.width * s;
    final newH = base.height * s;
    var cx = transform.centerX != null
        ? transform.centerX! * playW
        : base.center.dx;
    var cy = transform.centerY != null
        ? transform.centerY! * playH
        : base.center.dy;

    if (id == PlayElementId.game) {
      // Keep the full game frame inside the play area (edges = hard limit).
      final halfW = newW / 2;
      final halfH = newH / 2;
      cx = cx.clamp(halfW, playW - halfW);
      cy = cy.clamp(halfH, playH - halfH);
    } else {
      // Controls: keep at least half of the hit target on-screen.
      cx = cx.clamp(0.0, playW);
      cy = cy.clamp(0.0, playH);
    }

    return Rect.fromCenter(
      center: Offset(cx, cy),
      width: newW,
      height: newH,
    );
  }
}
