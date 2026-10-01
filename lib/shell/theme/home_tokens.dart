import 'package:flutter/material.dart';

import '../common/lemon_loading.dart';

/// Layout / chrome tokens for the Switch-style home shelf.
///
/// 4pt grid aligned with play tokens — keep free-floating magic numbers out of
/// home widgets.
abstract final class HomeSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const double screenPadH = xl;
  static const double screenPadV = md;
  static const double topBarHeight = 56;
  static const double sectionGap = lg;
  static const double rowLabelGap = sm;
  static const double tileGap = md;

  /// Vertical gap between library grid rows (title already inside each cell).
  static const double libraryRowGap = sm; // 8

  // ── Library bottom sheets ────────────────────────────────────────────────

  /// Sheet title row (not list items).
  static const double sheetTitlePadH = lg; // 16

  /// List / action / check rows.
  static const double sheetListPadH = xl; // 24

  /// Icon or circle-check → label.
  static const double sheetIconLabelGap = md; // 12

  // ── Form sub-pages (Game display, …) ─────────────────────────────────────

  /// Related stack in one column (art → description). Keep tight.
  static const double formStackGap = md; // 12

  /// Separate blocks (groups ↔ remove). Slightly airier than stack.
  static const double formSectionGap = lg; // 16

  /// Avatar ↔ cover, left column ↔ right column.
  static const double formArtGap = md; // 12
  static const double formColGap = lg; // 16

  /// Default content pad (IME closed). Prefer [formContentPadFor] on forms.
  static const EdgeInsets formContentPad = EdgeInsets.fromLTRB(
    screenPadH,
    xs, // 4 — header already gives air
    screenPadH,
    lg,
  );

  /// Form body pad — collapse bottom when IME is open (avoids black strip).
  static EdgeInsets formContentPadFor({required bool imeOpen}) =>
      EdgeInsets.fromLTRB(screenPadH, xs, screenPadH, imeOpen ? 0 : lg);
}

abstract final class HomeSizes {
  /// Square game tiles (width / height).
  static const double tileAspect = 1.0;

  /// Home shelf tile size as fraction of body height.
  static const double continueTileOfH = 0.54;

  static const double tileRadius = 14;

  /// Outer focus ring stroke (drawn outside the tile face).
  static const double focusRingWidth = 2.5;

  /// Gap between focus ring and tile face (black cushion — keep roomy for focus feel).
  static const double focusRingPad = 4;
  static const double monogramSize = 30;
  static const double titleSize = 14;
  static const double sectionLabelSize = 11;
  static const double brandSize = 24;
  static const double addTileIcon = 34;

  /// Cover → title under a game tile ([GameTile]).
  static const double tileTitleGap = 6;

  /// Full under-cover block: gap + label + small bottom air.
  /// Used by library grid aspect ratio and home shelf row height.
  static const double tileTitleBlock = tileTitleGap + titleSize + 2; // 22

  static const double continueTileMinH = 104;
  static const double continueTileMaxH = 196;

  /// Light Gaussian blur — soft focus, art still readable underneath.
  static const double backdropBlur = 8;

  // ── Chrome titles / header actions ───────────────────────────────────────

  static const double headerTitleSize = 18;

  /// Circular Settings / Add (home) and Save slot width (display).
  static const double headerActionSize = 48;
  static const double headerActionIcon = 20;
  static const double headerSpinnerSize = 18;

  // ── Library header chips ─────────────────────────────────────────────────

  static const double chipRadius = 20;
  static const double chipLabelSize = 13;
  static const double chipCountSize = 11;
  static const EdgeInsets chipPad = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );

  // ── Library sheets (action / check lists) ────────────────────────────────
  // Body/action match [formBodySize] — one primary text size for lists + forms.

  static const double sheetBodySize = formBodySize; // 14
  static const double sheetActionSize = formBodySize; // 14
  static const double sheetIconSize = 20;
  static const double sheetHeaderIconSize = 22;
  static const double sheetCheckSize = 18;
  static const double sheetCheckIconSize = 12;
  static const double miniAvatarSize = 40;
  static const double miniAvatarRadius = 8;
  static const double miniAvatarMonoSize = 12;

  // ── Tile import progress (post-add settle) ───────────────────────────────

  /// Fraction of tile width (centered) for the lemon bar.
  static const double importBarWidthFactor = 0.72;
  static const double importBarHeight = 5;
  static const double importBarBottomInset = 10;

  // ── Focus play-time badge (solid pill under the home shelf list) ────────

  static const double playTimeBadgeFont = 12;
  static const double playTimeBadgeRadius = 999;

  /// Gap between the game list row and the centered badge.
  static const double playTimeBadgeShelfGap = 18;

  /// Pill height (pad + line).
  static const double playTimeBadgeHeight = 24;

  /// Always-reserved strip under the shelf so focus does not jump layout.
  static const double playTimeBadgeSlot =
      playTimeBadgeShelfGap + playTimeBadgeHeight;

  static const EdgeInsets playTimeBadgePad = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 5,
  );

  // ── Empty states ─────────────────────────────────────────────────────────

  /// Library empty (grid) + home empty caption under the shelf row.
  static const double emptyIconSize = 40;
  static const double emptyTitleSize = 16;
  static const double emptyBodySize = 13;
  static const double emptyPadH = 32;

  // ── Form sub-pages (Game display, …) ─────────────────────────────────────

  static const double formAvatarSize = 112;
  static const double formCoverHeight = 112;

  /// Logical width used for form cover [ResizeImage] (preview, not full bleed).
  static const double formCoverPreviewW = 320;
  static const double formRadius = 14;
  static const double formSectionTitleSize = 13;

  /// Library grid column count from available body width.
  static int gridColumnCount(double width) {
    if (width >= 1100) return 8;
    if (width >= 900) return 7;
    if (width >= 700) return 6;
    if (width >= 480) return 5;
    return 3;
  }

  /// Square cover edge for a library grid of [gridWidth] (same math as grid layout).
  static double gridTileSize(double gridWidth) {
    final cols = gridColumnCount(gridWidth);
    return (gridWidth -
            HomeSpacing.screenPadH * 2 -
            HomeSpacing.tileGap * (cols - 1)) /
        cols;
  }

  /// First-page warm batch (boot dock + library open). ~2–3 rows at max cols.
  static const int libraryWarmBatch = 24;
  static const int artWarmBootBatch = libraryWarmBatch;

  /// Background fill: decode this many avatars, then yield to the UI.
  static const int artWarmChunk = 8;
  static const Duration artWarmChunkGap = Duration(milliseconds: 24);

  /// Extra rows ahead of the library viewport to warm while scrolling.
  static const int artWarmScrollLookaheadRows = 2;
  static const int artWarmScrollLookahead = 16;

  /// Primary UI body (forms, sheets, dialog content).
  static const double formBodySize = 14;
  static const double formHintSize = 12;
  static const double formBadgeSize = 10;
  static const double formPlaceholderIcon = 28;
  static const double formPlaceholderLabel = 11;
  static const double formSaveSlotW = 48;
  static const double formSaveSlotH = 24;
  static const double formSaveSpinner = 16;

  /// Overlay spinner on tile / backdrop pickers while copy + thumb run.
  static const double formArtSpinner = 28;

  /// Home/library confirms (landscape — tighter than [PlayModal.confirmMaxWidth]).
  static const double confirmDialogMaxWidth = 420;

  static const EdgeInsets confirmDialogInset = EdgeInsets.symmetric(
    horizontal: HomeSpacing.xl,
    vertical: HomeSpacing.xl,
  );

  /// Pill fields (search, new-group name).
  static const double pillRadius = 999;
}

abstract final class HomeMotion {
  static const Duration press = Duration(milliseconds: 90);
  static const double pressScale = 0.96;
  static const Curve pressCurve = Curves.easeOutCubic;

  /// Focus ring / tile chrome transitions.
  static const Duration focus = Duration(milliseconds: 220);
  static const Curve focusCurve = Curves.easeOutCubic;

  /// Bottom sheet / form pad when IME opens.
  static const Duration imePad = Duration(milliseconds: 100);
  static const Curve imePadCurve = Curves.decelerate;

  /// Soft reveal when a tile image was not already in the image cache.
  static const Duration artFadeIn = Duration(milliseconds: 160);
  static const Curve artFadeInCurve = Curves.easeOut;

  /// Cover backdrop cross-fade when focus / recent game changes.
  static const Duration backdrop = Duration(milliseconds: 420);

  /// Progress bar on a newly added shelf tile after import.
  static const Duration importProgress = Duration(milliseconds: 900);
  static const Curve importProgressCurve = Curves.easeOutCubic;

  /// Shelf snaps back to the first tile after add / return from play.
  static const Duration shelfScrollToStart = Duration(milliseconds: 320);
  static const Curve shelfScrollToStartCurve = Curves.easeOutCubic;

  /// Manual double-tap window. Avoid Flutter [GestureDetector.onDoubleTap]
  /// which delays every single tap (~300ms) waiting for a second tap.
  static const Duration doubleTapWindow = Duration(milliseconds: 280);

  /// First paint after lemon dock is fully gone — staged “gather in”.
  ///
  /// Must run only when [HomeScreen] is visible (not under the dock overlay).
  static const Duration bootReveal = Duration(milliseconds: 780);

  /// Heavy decelerate: long ease-out, no bounce — smooth and grounded.
  static const Curve bootRevealMotion = Cubic(0.22, 1.0, 0.36, 1.0);

  /// Cover soft-fades under the sliding chrome.
  static const Curve bootRevealBackdropCurve = Interval(
    0.0,
    0.45,
    curve: Curves.easeOut,
  );

  /// Header drops in first.
  static const Curve bootRevealHeaderSlide = Interval(
    0.0,
    0.55,
    curve: bootRevealMotion,
  );
  static const Curve bootRevealHeaderFade = Interval(
    0.0,
    0.42,
    curve: Curves.easeOut,
  );

  /// Fractional child height — starts fully above its own box.
  static const double bootRevealHeaderFromY = -1.15;

  /// Shelf follows slightly later, sliding in from the right.
  static const Curve bootRevealShelfSlide = Interval(
    0.12,
    0.92,
    curve: bootRevealMotion,
  );
  static const Curve bootRevealShelfFade = Interval(
    0.12,
    0.55,
    curve: Curves.easeOut,
  );

  /// Fractional child width — clear approach from the right.
  static const double bootRevealShelfFromX = 0.22;
}

abstract final class HomeColors {
  static const bg = LemonBrand.bg;
  static const lemon = LemonBrand.lemon;
  static const cream = LemonBrand.cream;

  /// Ink on lemon CTAs (settings add, sheet checks).
  static const onLemon = Color(0xFF0B0C10);

  static const tileFace = Color(0xFF1A1C24);
  static const tileFaceAlt = Color(0xFF22252F);
  static const tileBorder = Color(0xFF2A2E3A);
  static const labelDim = Color(0xFF8E8E9C);
  static const labelOn = Color(0xFFE8E8F0);
  static const missing = Color(0xFFFF8A8A);

  /// Soft dim over import progress + backdrop top.
  static const artScrim = Color(0x660B0C10);
  static const backdropScrimMid = Color(0x4D0B0C10);
  static const backdropScrimBottom = Color(0x990B0C10);

  /// Badge / clear-button scrims on art pickers.
  static const inkScrim = Color(0x8C0B0C10);

  /// Frosted play-time pill under the home game list (blurs cover backdrop).
  static const playTimeBadgeFill = Color(0x66FFFFFF);
  static const playTimeBadgeBorder = Color(0x59FFFFFF);
  static const playTimeBadgeText = Color(0xFFF5F5FA);

  static const tileShadow = Color(0x73000000);

  static const tileFaceGradient = [tileFaceAlt, tileFace, Color(0xFF12141A)];

  static const missingTileGradient = [Color(0xFF2A1A1A), Color(0xFF1A1212)];
}
