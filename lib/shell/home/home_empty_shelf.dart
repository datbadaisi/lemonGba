import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../common/dashed_rrect.dart';
import '../theme/home_tokens.dart';
import 'game_row.dart';
import 'game_tile.dart';
import 'home_shelf_metrics.dart';

/// Empty home body — same shelf geometry as the filled shelf, not a centered hero.
///
/// One real [AddGameTile] + soft ghost slots so the chrome matches the
/// Switch-style row users see after the first import.
class HomeEmptyShelf extends StatelessWidget {
  const HomeEmptyShelf({
    super.key,
    required this.busy,
    required this.onAdd,
  });

  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = HomeShelfMetrics.resolve(constraints.maxHeight);
        final tileSize = metrics.tileSize;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: metrics.shelfTop,
              left: 0,
              right: 0,
              height: metrics.rowHeight,
              child: GameRow(
                tileHeight: tileSize,
                children: [
                  AddGameTile(
                    size: tileSize,
                    enabled: !busy,
                    onTap: busy ? null : onAdd,
                  ),
                  GhostShelfTile(size: tileSize),
                  GhostShelfTile(size: tileSize),
                ],
              ),
            ),
            // Caption sits below the full content block (row + badge slot) so
            // empty/filled vertical chrome match [HomeShelfMetrics].
            if (metrics.spaceBelow > 0)
              Positioned(
                top: metrics.shelfTop + metrics.contentHeight,
                left: 0,
                right: 0,
                height: metrics.spaceBelow,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HomeSpacing.screenPadH,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Add a .gba ROM or Lemon full pack to start',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: HomeSizes.emptyBodySize,
                            height: 1.35,
                            color: HomeColors.labelDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Non-interactive empty slot — dashed frame + large image glyph.
///
/// Matches [AddGameTile] face geometry without the interactive label.
class GhostShelfTile extends StatelessWidget {
  const GhostShelfTile({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final borderColor = HomeColors.tileBorder.withValues(alpha: 0.42);
    final iconColor = HomeColors.labelDim.withValues(alpha: 0.34);
    final iconSize = (size * 0.42).clamp(32.0, 64.0);

    return ExcludeSemantics(
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
                    color: HomeColors.tileFace.withValues(alpha: 0.22),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedImage01,
                      size: iconSize,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: HomeSizes.tileTitleGap),
            const SizedBox(height: HomeSizes.titleSize + 2),
          ],
        ),
      ),
    );
  }
}
