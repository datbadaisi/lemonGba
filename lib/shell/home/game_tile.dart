import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../models/library_game.dart';
import '../common/dashed_rrect.dart';
import '../common/shell_art.dart';
import '../common/shell_pressable.dart';
import '../theme/home_tokens.dart';

/// Square game tile — full-title placeholder or avatar, focus ring, taps.
class GameTile extends StatefulWidget {
  const GameTile({
    super.key,
    required this.game,
    required this.size,
    required this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.focused = false,
    this.loading = false,
    this.avatarPath,
  });

  final LibraryGame game;

  /// Cover box edge length (square). Title sits below.
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final bool focused;

  /// Shows a lemon progress bar on the cover (e.g. just after import).
  final bool loading;
  final String? avatarPath;

  @override
  State<GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<GameTile> {
  bool _down = false;
  DateTime? _lastTapAt;

  /// Immediate single-tap; second tap within [HomeMotion.doubleTapWindow] = play.
  /// (Native [onDoubleTap] would delay every first tap while waiting.)
  void _handleTap() {
    if (widget.game.missing) return;
    final now = DateTime.now();
    final last = _lastTapAt;
    final isDouble =
        last != null &&
        now.difference(last) < HomeMotion.doubleTapWindow &&
        widget.onDoubleTap != null;

    if (isDouble) {
      _lastTapAt = null;
      widget.onDoubleTap!();
      return;
    }

    _lastTapAt = now;
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final focused = widget.focused;
    final faceBorder = game.missing
        ? HomeColors.missing.withValues(alpha: 0.7)
        : HomeColors.tileBorder;

    const pad = HomeSizes.focusRingPad;
    const ringW = HomeSizes.focusRingWidth;
    final outerRadius = HomeSizes.tileRadius + pad + ringW;

    final face = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HomeSizes.tileRadius),
        border: Border.all(
          color: focused ? Colors.transparent : faceBorder,
          width: 1,
        ),
        boxShadow: focused
            ? null
            : const [
                BoxShadow(
                  color: HomeColors.tileShadow,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HomeSizes.tileRadius - 0.5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _TileFace(
              game: game,
              avatarPath: widget.avatarPath,
              size: widget.size,
            ),
            if (widget.loading) const _TileImportProgress(),
          ],
        ),
      ),
    );

    final semanticLabel = game.missing
        ? '${game.title}, ROM missing'
        : game.title;
    final playHint = widget.onDoubleTap != null ? 'Double tap to play' : null;

    return Semantics(
      button: true,
      enabled: !game.missing,
      label: semanticLabel,
      hint: playHint,
      selected: focused,
      onTap: game.missing ? null : _handleTap,
      onLongPress: widget.onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: game.missing ? null : (_) => setState(() => _down = true),
        onTapUp: game.missing ? null : (_) => setState(() => _down = false),
        onTapCancel: game.missing ? null : () => setState(() => _down = false),
        onTap: game.missing ? null : _handleTap,
        onLongPress: widget.onLongPress,
        child: ShellPressScale(
          pressed: _down,
          child: SizedBox(
            width: widget.size,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: HomeMotion.focus,
                    curve: HomeMotion.focusCurve,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        focused ? outerRadius : HomeSizes.tileRadius,
                      ),
                      border: focused
                          ? Border.all(color: HomeColors.lemon, width: ringW)
                          : null,
                      color: focused ? HomeColors.bg : Colors.transparent,
                      boxShadow: focused
                          ? [
                              BoxShadow(
                                color: HomeColors.lemon.withValues(alpha: 0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    padding: focused
                        ? const EdgeInsets.all(pad)
                        : EdgeInsets.zero,
                    child: face,
                  ),
                ),
                const SizedBox(height: HomeSizes.tileTitleGap),
                Text(
                  game.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: HomeSizes.titleSize,
                    fontWeight: focused ? FontWeight.w800 : FontWeight.w600,
                    color: game.missing
                        ? HomeColors.missing
                        : focused
                        ? HomeColors.lemon
                        : HomeColors.labelOn,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileImportProgress extends StatelessWidget {
  const _TileImportProgress();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: HomeColors.artScrim),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: HomeSizes.importBarBottomInset,
            ),
            child: FractionallySizedBox(
              widthFactor: HomeSizes.importBarWidthFactor,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: HomeMotion.importProgress,
                curve: HomeMotion.importProgressCurve,
                builder: (context, value, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(
                      HomeSizes.importBarHeight,
                    ),
                    child: SizedBox(
                      height: HomeSizes.importBarHeight,
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: HomeSizes.importBarHeight,
                        backgroundColor: HomeColors.onLemon.withValues(
                          alpha: 0.45,
                        ),
                        color: HomeColors.lemon,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Semi-opaque play-time pill (home shelf places this under the whole list).
///
/// Solid fill only — no [BackdropFilter] blur (costly on mobile GPUs when the
/// focus target changes over animated cover backdrops).
class PlayTimeBadge extends StatelessWidget {
  const PlayTimeBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Play time $label',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HomeColors.playTimeBadgeFill,
          borderRadius: BorderRadius.circular(
            HomeSizes.playTimeBadgeRadius,
          ),
          border: Border.all(
            color: HomeColors.playTimeBadgeBorder,
            width: 1,
          ),
        ),
        child: Padding(
          padding: HomeSizes.playTimeBadgePad,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: HomeSizes.playTimeBadgeFont,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: HomeColors.playTimeBadgeText,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _TileFace extends StatelessWidget {
  const _TileFace({required this.game, required this.size, this.avatarPath});

  final LibraryGame game;
  final double size;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final placeholder = ShellTilePlaceholder(game: game, size: size);
    // Canonical size shared with library warm — not [size], or cache misses.
    final cache = ShellArt.avatarMemCacheWidth(context);

    return ShellCoverImage(
      path: avatarPath,
      memCacheWidth: cache,
      placeholder: placeholder,
      underColor: HomeColors.tileFace,
    );
  }
}

/// Last home-shelf slot: open the full library grid (recent order).
class MoreGamesTile extends StatelessWidget {
  const MoreGamesTile({
    super.key,
    required this.size,
    required this.onTap,
    this.totalCount,
  });

  final double size;
  final VoidCallback onTap;
  final int? totalCount;

  @override
  Widget build(BuildContext context) {
    final label = totalCount != null ? 'All ($totalCount)' : 'All games';

    return Semantics(
      button: true,
      label: label,
      child: ShellPressable(
        onTap: onTap,
        child: SizedBox(
          width: size,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(HomeSizes.tileRadius),
                    border: Border.all(
                      color: HomeColors.tileBorder,
                      width: 1.5,
                    ),
                    color: HomeColors.tileFace,
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedMenu01,
                      size: HomeSizes.addTileIcon,
                      color: HomeColors.cream,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: HomeSizes.tileTitleGap),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: HomeSizes.titleSize,
                  fontWeight: FontWeight.w600,
                  color: HomeColors.labelDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trailing “+” shelf slot to add a game (Switch empty-slot vibe).
class AddGameTile extends StatelessWidget {
  const AddGameTile({
    super.key,
    required this.size,
    required this.onTap,
    this.enabled = true,
  });

  final double size;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Large image glyph — matches empty ghost slots at shelf scale.
    final iconSize = (size * 0.42).clamp(36.0, 64.0);
    final accent = enabled
        ? HomeColors.lemon
        : HomeColors.lemon.withValues(alpha: 0.4);
    final borderColor = enabled
        ? HomeColors.lemon.withValues(alpha: 0.75)
        : HomeColors.lemon.withValues(alpha: 0.35);

    return Semantics(
      button: true,
      enabled: enabled && onTap != null,
      label: 'Add game',
      child: ShellPressable(
        enabled: enabled,
        onTap: onTap,
        child: SizedBox(
          width: size,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CustomPaint(
                  painter: DashedRRectPainter(
                    color: borderColor,
                    radius: HomeSizes.tileRadius,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(HomeSizes.tileRadius),
                      color: HomeColors.tileFace.withValues(alpha: 0.6),
                    ),
                    child: Center(
                      child: HugeIcon(
                        // Same image glyph as empty ghost slots.
                        icon: HugeIcons.strokeRoundedImage01,
                        size: iconSize,
                        color: accent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: HomeSizes.tileTitleGap),
              Text(
                'Add game',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: HomeSizes.titleSize,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
