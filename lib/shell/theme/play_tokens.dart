import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 4pt spacing scale for the play (in-game) surface.
///
/// Commercial layout discipline: every edge, gap, and clamp comes from here —
/// no free-floating magic numbers in [GameScreen] / pad widgets.
abstract final class PlaySpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Outer inset for primary controls (D-pad, A/B, menu).
  static const double edge = lg; // 16

  /// Minimum inset when clamping frame-hugging controls.
  static const double edgeMin = sm; // 8

  /// Horizontal gap between game frame and L/R / Select / Start.
  static const double gapToFrame = md; // 12

  /// Error / empty-state content padding.
  static const double content = xl; // 24

  /// Vertical rhythm inside error pane.
  static const double stackTight = md; // 12
  static const double stack = lg; // 16
}

/// In-game pause menu — full-height bottom sheet tokens.
///
/// Keeps [GameScreen] free of free-floating modal magic numbers. Scale follows
/// the same 4pt grid as [PlaySpacing].
abstract final class PlayModal {
  // ── Sheet geometry ────────────────────────────────────────────────────────

  /// Top corners of the full-height bottom sheet.
  static const double sheetTopRadius = 22;

  /// Cap sheet width (landscape otherwise stretches edge-to-edge).
  static const double sheetMaxWidth = 510;

  /// Drag handle chip.
  static const double sheetHandleWidth = 36;
  static const double sheetHandleHeight = 4;
  static const double sheetHandleRadius = 2;

  /// Confirm dialog (New Game, etc.) — same cap as home library confirms.
  static const double confirmMaxWidth = 420;
  static const double confirmRadius = 28;
  static const EdgeInsets confirmInsetPadding = EdgeInsets.symmetric(
    horizontal: PlaySpacing.sm, // 8
    vertical: PlaySpacing.xl, // 24
  );
  static const EdgeInsets confirmTitlePadding = EdgeInsets.fromLTRB(
    PlaySpacing.xxl + PlaySpacing.xs, // 36
    PlaySpacing.xxl, // 32
    PlaySpacing.xxl + PlaySpacing.xs, // 36
    PlaySpacing.lg, // 16
  );
  static const EdgeInsets confirmContentPadding = EdgeInsets.fromLTRB(
    PlaySpacing.xxl + PlaySpacing.xs, // 36
    0,
    PlaySpacing.xxl + PlaySpacing.xs, // 36
    PlaySpacing.xl, // 24
  );
  static const EdgeInsets confirmActionsPadding = EdgeInsets.fromLTRB(
    PlaySpacing.xl, // 24
    0,
    PlaySpacing.xl, // 24
    PlaySpacing.xl, // 24
  );
  static const double confirmTitleSize = 20;
  static const double confirmBodySize = 16;

  /// Outer inset used by toast / overlays near screen edges.
  static const double screenMargin = PlaySpacing.xl; // 24

  // ── Internal spacing ──────────────────────────────────────────────────────

  /// Sheet content inset.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(
    PlaySpacing.lg + PlaySpacing.xs, // 20
    PlaySpacing.sm, // 8
    PlaySpacing.lg + PlaySpacing.xs, // 20
    PlaySpacing.lg, // 16
  );

  /// Menu list tile horizontal inset.
  static const double tilePadH = PlaySpacing.md; // 12

  /// Menu list tile vertical inset (ListTile contentPadding).
  /// Kept modest — ListTile min height already gives a solid tap target.
  static const double tilePadV = PlaySpacing.xs + 2; // 6

  /// Extra air between main-menu action rows (0 = rely on tile pad only).
  static const double tileGap = 0;

  /// Save-slot row padding (two-line label needs a little vertical room).
  static const EdgeInsets slotPadding = EdgeInsets.symmetric(
    horizontal: PlaySpacing.sm, // 8
    vertical: PlaySpacing.sm + 2, // 10
  );

  /// Gap between SAVE and LOAD.
  static const double actionGap = PlaySpacing.sm; // 8

  /// Vertical rhythm around the quick-save / manual slots divider.
  static const double slotDividerPadV = PlaySpacing.sm; // 8

  /// Header back-icon → title.
  static const double headerIconGap = PlaySpacing.sm; // 8

  // ── Component sizes ───────────────────────────────────────────────────────

  static const double tileIcon = 20;
  static const double headerIcon = 18;
  static const double backIcon = 16;
  static const double trailingIcon = 18;

  /// Full stadium / pill radius for SAVE·LOAD chips.
  static const double actionRadius = 999;
  static const double tileRadius = PlaySpacing.md; // 12
  static const double titleSize = 13;
  static const double titleTracking = 1.2;
  static const double tileTitleSize = 14;
  static const double slotLabelSize = 13;
  static const double slotMetaSize = 11;
  static const double actionFont = 11;
  static const double actionTracking = 0.5;

  /// Horizontal bias so pills read as capsules, not short chips.
  static const EdgeInsets actionPadding = EdgeInsets.symmetric(
    horizontal: PlaySpacing.lg, // 16
    vertical: PlaySpacing.sm, // 8
  );

  // ── Solid panel chrome ────────────────────────────────────────────────────
  //
  // Cool ink surface (not warm charcoal plastic). Flat, near-black, slight blue
  // undertone — reads modern on OLED pure black instead of dated grey shells.

  /// Panel face — cool zinc/ink.
  static const Color surface = Color(0xFF16181F);

  /// Hairline rim (cool slate, not muddy grey).
  static const Color border = Color(0xFF2A2E3A);

  static const double barrierOpacity = 0.5;

  /// Extra dim when a confirm dialog sits on top of the already-open sheet.
  static const double nestedBarrierOpacity = 0.32;

  // ── On-surface text / ink (pause sheet — replaces Colors.white + alpha) ──

  static const Color onSurface = Color(0xFFFFFFFF);

  /// Section titles (“GAME MENU”).
  static const Color title = Color(0xE6FFFFFF); // ~0.90

  /// Confirm / body secondary.
  static const Color body = Color(0xA6FFFFFF); // ~0.65

  /// Trailing chevrons.
  static const Color chevron = Color(0x73FFFFFF); // ~0.45

  /// Back arrow on sub-pages.
  static const Color iconBack = Color(0xD9FFFFFF); // ~0.85

  /// Close / muted header icons.
  static const Color iconMuted = Color(0xA6FFFFFF); // ~0.65

  /// Drag handle chip.
  static const Color handle = Color(0x38FFFFFF); // ~0.22

  /// ListTile / InkWell splash & hover.
  static const Color inkSplash = Color(0x14FFFFFF); // ~0.08
  static const Color inkHover = Color(0x0AFFFFFF); // ~0.04

  /// Save-slot title (last-used vs normal).
  static const Color slotLabelHot = Color(0xF2FFFFFF); // ~0.95
  static const Color slotLabel = Color(0xE0FFFFFF); // ~0.88
  static const Color slotMetaEmpty = Color(0x61FFFFFF); // ~0.38
  static const Color slotMetaHot = Color(0xB8FFFFFF); // ~0.72
  static const Color slotMeta = Color(0x9EFFFFFF); // ~0.62

  /// SAVE / LOAD chips.
  static const Color actionFillDisabled = Color(0x0AFFFFFF);
  static const Color actionFillPrimary = Color(0x29FFFFFF); // ~0.16
  static const Color actionFill = Color(0x12FFFFFF); // ~0.07
  static const Color actionBorderDisabled = Color(0x14FFFFFF);
  static const Color actionBorderPrimary = Color(0x4DFFFFFF); // ~0.30
  static const Color actionBorder = Color(0x29FFFFFF);
  static const Color actionTextDisabled = Color(0x47FFFFFF); // ~0.28
  static const Color actionText = Color(0xD9FFFFFF); // ~0.85

  static const Color confirmTitle = Color(0xEBFFFFFF); // ~0.92
  static const Color confirmCancel = Color(0xB3FFFFFF); // ~0.70

  /// Destructive (New Game / Save & Exit) — same hex as home missing.
  static const Color danger = Color(0xFFFF8A8A);

  static const Color textShadow = Color(0x99000000);
  static const double textShadowBlur = 8;
  static const List<Shadow> titleShadows = [
    Shadow(color: textShadow, blurRadius: textShadowBlur),
  ];

  // ── Toast chip (Overlay-based; not Material SnackBar) ─────────────────────

  static const double toastRadius = 16;
  static const double toastMaxWidth = 320;
  static const Duration toastDuration = Duration(seconds: 2);
  static const Duration toastEnterDuration = Duration(milliseconds: 220);
  static const Curve toastEnterCurve = Curves.easeOutCubic;
  static const double toastSlide = 18;
  static const EdgeInsets toastPadding = EdgeInsets.symmetric(
    horizontal: PlaySpacing.md + 2, // 14
    vertical: PlaySpacing.md, // 12
  );

  /// Flat ink chip — no boxShadow (avoids dark rectangular smear under toast).
  static BoxDecoration toastDecoration() {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(toastRadius),
      border: Border.all(color: border, width: 1),
    );
  }

  // ── In-play speed HUD (free-floating snackbar, AppToast placement) ────────

  /// How long the speed chip stays after cycle / drag.
  static const Duration speedHudDuration = Duration(milliseconds: 1800);
  static const Duration speedHudEnterDuration = Duration(milliseconds: 220);
  static const Curve speedHudEnterCurve = Curves.easeOutCubic;
  static const double speedHudSlide = 14;
  static const double speedHudMaxWidth = 300;
  static const double speedHudRadius = 14;
  static const EdgeInsets speedHudPadding = EdgeInsets.fromLTRB(
    PlaySpacing.md, // 12
    PlaySpacing.xs + 2, // 6
    PlaySpacing.md, // 12
    PlaySpacing.xs + 2, // 6
  );

  /// Discrete speed slider track height / thumb.
  static const double speedSliderTrackH = 3;
  static const double speedSliderThumb = 16;
  /// Compact HUD row height (Material Slider is forced into this).
  static const double speedHudSliderH = 28;
  static const double speedHudThumb = 12;
  static const double speedLabelSize = 12;
  static const double speedValueSize = 13;

  // ── Motion ────────────────────────────────────────────────────────────────

  /// Modal sheet open — Material default (`_bottomSheetEnterDuration`).
  static const Duration sheetEnterDuration = Duration(milliseconds: 250);

  /// Modal sheet dismiss slide — Material default (`_bottomSheetExitDuration`).
  /// Independent of [AppSfx.tapSettle] (audio hold-off can be longer).
  static const Duration sheetExitDuration = Duration(milliseconds: 200);

  /// Menu ↔ states: directional slide + fade inside the fixed sheet.
  static const Duration pageDuration = Duration(milliseconds: 280);
  static const Curve pageCurve = Curves.easeOutCubic;
  static const Curve pageReverseCurve = Curves.easeInCubic;

  /// Horizontal slide fraction for push/pop between sheet pages.
  static const double pageSlide = 0.08;
}

/// Control sizes, ratios, and motion micro-tokens for the virtual GBA shell.
abstract final class PlaySizes {
  // ── Screen ratios (landscape height = reference) ──────────────────────────

  /// D-pad outer size as a fraction of play-area height.
  static const double dpadOfH = 0.38;

  /// Face A/B diameter as a fraction of play-area height.
  static const double faceOfH = 0.15;

  /// A/B cluster width = face × this factor (diagonal layout).
  static const double faceClusterScale = 2.35;

  /// A/B cluster height = cluster width × this factor.
  static const double faceClusterAspect = 0.92;

  /// Select / Start pill height as a fraction of play-area height.
  /// Taller than before; extra height opens downward (top stays pinned).
  static const double metaHOfH = 0.09;

  /// Select / Start pill width as a fraction of play-area height.
  static const double metaWOfH = 0.22;

  /// Menu (⋯) diameter as a fraction of play-area height.
  /// Larger than meta height so the button stays easy to tap in landscape.
  static const double menuOfH = 0.12;

  /// L / R shoulder height as a fraction of play-area height.
  /// Taller than before; extra height opens toward the top (bottom stays pinned).
  static const double shoulderHOfH = 0.11;

  /// L / R shoulder width as a fraction of play-area height.
  static const double shoulderWOfH = 0.23;

  /// Legacy overhang fraction (used only to pin historical control edges).
  static const double frameOverhang = 0.35;

  /// How far the bottom of L/R sits below the game-frame top (play-height fraction).
  /// Matches the old 0.09 × (1 − frameOverhang) bottom so height increases grow up only.
  static const double shoulderHangBelowOfH = 0.09 * (1.0 - frameOverhang);

  /// How far the top of Select/Start sits above the game-frame bottom (play-height fraction).
  /// Matches the old 0.075 × (1 − frameOverhang) top so height increases grow down only.
  static const double metaHangAboveOfH = 0.075 * (1.0 - frameOverhang);

  /// Game display vertical inset = height × this, then clamped.
  static const double gameInsetOfH = 0.12;

  static const double gameInsetMin = 36;
  static const double gameInsetMax = 56;

  // ── Absolute defaults (desktop / fallback) ────────────────────────────────

  static const double dpadDefault = 168;
  static const double faceDefault = 58;
  static const double metaWDefault = 72;
  static const double metaHDefault = 34;
  static const double shoulderWDefault = 92;
  static const double shoulderHDefault = 44;
  static const double menuDefault = 48;

  /// Absolute clamp for menu (⋯) diameter after ratio resolve.
  static const double menuMin = 44;
  static const double menuMax = 56;

  // ── Geometry ──────────────────────────────────────────────────────────────

  static const double shoulderRadius = 10;
  static const double dpadArmRatio = 0.34;
  static const double dpadDeadZone = 0.12;
  static const double dpadCornerThreshold = 0.38;
  static const double dpadInsetRatio = 0.14;
  static const double dpadCornerRadiusRatio = 0.18;

  // ── Press / rocker motion ─────────────────────────────────────────────────

  static const Duration pressDuration = Duration(milliseconds: 70);
  static const double pressSink = 2;
  static const double pressSinkLight = 1.5;
  static const double pressScale = 0.94;
  static const double pressScaleIcon = 0.88;
  static const double rockerTilt = 0.24;
  static const double rockerShift = 2.5;
  static const double rockerPerspective = 0.0022;

  /// Symmetric cardinal nudge when an arm is active (GBA rocker feel).
  static const double arrowNudge = 2;

  // ── Shadow ────────────────────────────────────────────────────────────────

  static const double shadowBlur = 3.5;
  static const double shadowBlurPressed = 5;
  static const double shadowY = 2.5;
  static const double shadowSlide = 5;
  static const double shadowYPressedBase = 2;

  // ── Type ──────────────────────────────────────────────────────────────────

  static const double shoulderFont = 14;
  static const double shoulderLetterSpacing = 1.2;
  static const double metaLetterSpacing = 0.8;
  static const double faceFontRatio = 0.34;
  static const double metaFontRatio = 0.42;
  static const double menuIconRatio = 0.5;
  static const double dpadArrowIcon = 28;
  static const double errorIcon = 48;

  /// User-pause glyph (double-tap) in the game-frame corner.
  static const double pauseIcon = 22;

  /// Opacity for pad widgets that overlap the game frame (see-through controls).
  static const double overlapOpacity = 0.45;
}

/// Shared OLED plastic palette for the virtual pad (single source of truth).
///
/// Tuned for pure black (#000) play bg: solid charcoal shells with soft lift,
/// not frosted glass (glass washed out on OLED black).
abstract final class PlayColors {
  /// Main shell body — charcoal, slightly lifted off pure black.
  static const plastic = Color(0xFF2C2C36);

  /// Deep shell / gradient foot.
  static const plasticDark = Color(0xFF1A1A22);

  /// Soft rim highlight (not bright gray).
  static const plasticEdge = Color(0xFF48485A);

  /// D-pad recessed face.
  static const dpadFace = Color(0xFF121218);

  static const labelDim = Color(0xFF8E8E9C);
  static const labelOn = Color(0xFFE0E0EA);
  static const playBg = Color(0xFF000000);
  static const framePlaceholder = Color(0xFF101010);

  /// Pause icon on the game frame (readable on bright/dark scenes).
  static const pauseIcon = Color(0xE6FFFFFF);

  /// Success green (toasts, etc.).
  static const success = Color(0xFF7CFF9A);

  /// Destructive / toast error — shared hex with home missing.
  static const danger = Color(0xFFFF8A8A);
  static const error = danger;

  /// Soft press shade on plastic buttons (outer → clear).
  static const pressScrimOuter = Color(0x52000000);
  static const pressScrimMid = Color(0x1A000000);
  static const pressScrimClear = Color(0x00000000);
  static const List<Color> pressScrimGradient = [
    pressScrimOuter,
    pressScrimMid,
    pressScrimClear,
  ];
  static const List<double> pressScrimStops = [0.0, 0.4, 0.72];

  /// Arrow glyph when d-pad arm is inactive.
  static const dpadArrowIdle = Color(0x8AFFFFFF); // ~white54

  static List<Color> shellGradient({required bool down}) => down
      ? const [Color(0xFF32323E), Color(0xFF24242E), Color(0xFF16161C)]
      : const [Color(0xFF383844), plastic, plasticDark];
}

/// Shared press transform used by shell buttons.
Matrix4 playPressTransform({
  required bool down,
  double sink = PlaySizes.pressSink,
}) {
  if (!down) return Matrix4.identity();
  return Matrix4.identity()
    ..translateByDouble(0, sink, 0, 1)
    ..scaleByDouble(PlaySizes.pressScale, PlaySizes.pressScale, 1, 1);
}

List<BoxShadow>? playShellShadow({required bool down}) {
  if (down) return null;
  // Soft lift only — on OLED black, heavy gray shadows look like dirty boxes.
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.55),
      blurRadius: PlaySizes.shadowBlur,
      offset: const Offset(0, PlaySizes.shadowY),
    ),
  ];
}

/// Utility used by D-pad painter for unit tilt direction.
(double, double) playTiltUnit({
  required bool left,
  required bool right,
  required bool up,
  required bool down,
}) {
  var tx = 0.0;
  var ty = 0.0;
  if (left) tx -= 1;
  if (right) tx += 1;
  if (up) ty -= 1;
  if (down) ty += 1;
  final mag = tx * tx + ty * ty;
  if (mag > 0) {
    final s = 1 / (mag > 1 ? math.sqrt2 : 1.0);
    tx *= s;
    ty *= s;
  }
  return (tx, ty);
}
