import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../models/library_game.dart';
import '../theme/home_tokens.dart';
import 'shell_file_image.dart';

/// Shell art paint helpers + decode sizes.
///
/// Warming / scheduling for large libraries lives in [ShellArtWarmer]
/// (boot batch → visible window → chunked background).
///
/// 1. **One avatar decode size** — [avatarMemCacheWidth] for every [GameTile].
/// 2. **Paint** only through [ShellCoverImage] / [ShellFileImage].
/// 3. No `existsSync` on the UI thread.
abstract final class ShellArt {
  /// Raises Flutter's image cache so a full library of tiles stays resident.
  static void configureImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    // 100 avatars + backdrops + UI; leave headroom for scroll thrash.
    if (cache.maximumSize < 250) cache.maximumSize = 250;
    if (cache.maximumSizeBytes < 140 << 20) {
      cache.maximumSizeBytes = 140 << 20; // 140 MiB
    }
  }

  /// Canonical avatar decode width (physical px) shared by shelf + library.
  ///
  /// Disk thumbs are already ≤[ArtThumbnailer.tileMaxEdge]; this cap matches
  /// that so we never re-decode larger than the file on disk.
  static int avatarMemCacheWidth(BuildContext context) {
    final mq = MediaQuery.of(context);
    final shelfMax = HomeSizes.continueTileMaxH;
    final gridTile = HomeSizes.gridTileSize(mq.size.width);
    final logical = math.max(shelfMax, gridTile);
    // Match disk tile max (768); decoding sharper than the PNG is wasted.
    return ShellFileImage.cachePx(logical, mq.devicePixelRatio, max: 768);
  }

  /// @nodoc kept name for call sites that pass layout size — ignored for key.
  static int tileCachePx(BuildContext context, double logical) {
    // Deliberately ignore [logical]: one key for all tiles.
    return avatarMemCacheWidth(context);
  }

  static int miniAvatarCachePx(BuildContext context) {
    // Mini faces are small; still share avatar cache when path is the same
    // only if width matches. Mini uses its own key (OK — rare / sheets only).
    return ShellFileImage.cachePx(
      HomeSizes.miniAvatarSize,
      MediaQuery.devicePixelRatioOf(context),
      max: 160,
    );
  }

  /// Longest screen edge — backdrop only (not shared with tiles).
  static int backdropCachePx(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ShellFileImage.cachePx(
      mq.size.longestSide,
      mq.devicePixelRatio,
      max: 1280,
    );
  }

  static int formAvatarCachePx(BuildContext context) {
    // Full device pixels for the form preview (was capped at 256 → soft on
    // 3× displays where 112 logical needs ~336 decode px).
    return ShellFileImage.cachePx(
      HomeSizes.formAvatarSize,
      MediaQuery.devicePixelRatioOf(context),
      max: 768,
    );
  }

  static int formCoverCachePx(BuildContext context) {
    return ShellFileImage.cachePx(
      HomeSizes.formCoverPreviewW,
      MediaQuery.devicePixelRatioOf(context),
      max: 768,
    );
  }

  static double estimateLibraryTileLogical(BuildContext context) {
    return HomeSizes.gridTileSize(MediaQuery.sizeOf(context).width);
  }

}

/// Local cover/avatar. Prefer paths already warmed by [ShellArtWarmer]
/// so the first frame is synchronous from Flutter's image cache.
class ShellCoverImage extends StatelessWidget {
  const ShellCoverImage({
    super.key,
    required this.path,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    // medium: box art stays crisp when downscaled; low looked mushy on tiles.
    this.filterQuality = FilterQuality.medium,
    this.underColor = HomeColors.tileFace,
  });

  final String? path;
  final Widget placeholder;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final FilterQuality filterQuality;
  final Color underColor;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null || p.isEmpty) return placeholder;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: underColor),
        // Key on path so a replace that mints a new file never reuses the
        // previous Image element / gapless frame under the same Element.
        ShellFileImage(
          key: ValueKey<String>(p),
          path: p,
          fit: fit,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
          filterQuality: filterQuality,
          fadeIn: true,
          errorBuilder: (context, error, stackTrace) => placeholder,
        ),
      ],
    );
  }
}

/// Empty tile face: full game title, wraps then scales inside the box.
class ShellTilePlaceholder extends StatelessWidget {
  const ShellTilePlaceholder({
    super.key,
    required this.game,
    required this.size,
  });

  final LibraryGame game;
  final double size;

  @override
  Widget build(BuildContext context) {
    final titleColor = game.missing ? HomeColors.missing : HomeColors.lemon;
    final maxFont = (size * 0.17).clamp(13.0, 20.0);
    final padH = (size * 0.1).clamp(6.0, 14.0);
    final padV = (size * 0.12).clamp(8.0, 16.0);
    final textWidth = (size - padH * 2).clamp(24.0, size);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: game.missing
              ? HomeColors.missingTileGradient
              : HomeColors.tileFaceGradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: size * 0.55,
              height: size * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HomeColors.lemon.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: textWidth),
                    child: Text(
                      game.title,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: maxFont,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        height: 1.15,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (game.missing)
            Positioned(
              top: 6,
              left: 6,
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: 14,
                color: HomeColors.missing.withValues(alpha: 0.9),
              ),
            ),
        ],
      ),
    );
  }
}

/// Form / sheet empty art: monogram or “add image” label.
class ShellArtPlaceholder extends StatelessWidget {
  const ShellArtPlaceholder({super.key, this.monogram, this.label});

  final String? monogram;
  final String? label;

  @override
  Widget build(BuildContext context) {
    // Transparent on black form surfaces — avoid gray tile fill.
    return ColoredBox(
      color: HomeColors.bg,
      child: Center(
        child: monogram != null
            ? Text(
                monogram!,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: HomeSizes.monogramSize,
                  color: HomeColors.lemon,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedImageAdd01,
                    size: HomeSizes.formPlaceholderIcon,
                    color: HomeColors.labelDim,
                  ),
                  if (label != null) ...[
                    const SizedBox(height: HomeSpacing.sm),
                    Text(
                      label!,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: HomeSizes.formPlaceholderLabel,
                        color: HomeColors.labelDim,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Compact monogram-or-file avatar for sheets and lists.
class ShellMiniAvatar extends StatelessWidget {
  const ShellMiniAvatar({super.key, required this.monogram, this.path});

  final String monogram;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final cache = ShellArt.miniAvatarCachePx(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(HomeSizes.miniAvatarRadius),
      child: SizedBox(
        width: HomeSizes.miniAvatarSize,
        height: HomeSizes.miniAvatarSize,
        child: ShellCoverImage(
          path: path,
          underColor: HomeColors.tileFaceAlt,
          memCacheWidth: cache,
          placeholder: ColoredBox(
            color: HomeColors.tileFaceAlt,
            child: Center(
              child: Text(
                monogram,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: HomeSizes.miniAvatarMonoSize,
                  color: HomeColors.lemon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
