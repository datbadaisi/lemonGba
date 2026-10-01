import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/home_tokens.dart';

/// Shared local-file image for shell art (tile avatar, cover, backdrop).
///
/// Why this exists: raw [Image.file] at every call site caused visible pop-in
/// (blank frame while decoding) and full-res decodes for tiny tiles. This
/// widget standardizes:
/// - [gaplessPlayback] so provider swaps keep the last frame
/// - optional [memCacheWidth]/[memCacheHeight] via [ResizeImage]
/// - [ResizeImagePolicy.fit] so aspect is never stretched
/// - fade-in when decode is async (cached loads paint immediately)
/// - consistent error fallback
class ShellFileImage extends StatelessWidget {
  const ShellFileImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    // medium is the shell default for box art (sharper than low, cheaper than high).
    this.filterQuality = FilterQuality.medium,
    this.fadeIn = true,
    this.errorBuilder,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Decode width in physical pixels (pass `logical * devicePixelRatio`).
  final int? memCacheWidth;

  /// Decode height in physical pixels.
  final int? memCacheHeight;

  final FilterQuality filterQuality;

  /// Soft opacity reveal when the first frame is not synchronous.
  final bool fadeIn;

  final ImageErrorWidgetBuilder? errorBuilder;

  /// Image provider used by both paint and [precache].
  ///
  /// Important: [ResizeImage] defaults to [ResizeImagePolicy.exact], which
  /// **stretches** when both width and height are set. We always use
  /// [ResizeImagePolicy.fit] so aspect ratio is preserved; [BoxFit.cover] on
  /// the [Image] handles crop-to-frame.
  static ImageProvider provider(
    String path, {
    int? memCacheWidth,
    int? memCacheHeight,
  }) {
    ImageProvider image = FileImage(File(path));
    if (memCacheWidth != null || memCacheHeight != null) {
      image = ResizeImage(
        image,
        width: memCacheWidth,
        height: memCacheHeight,
        policy: ResizeImagePolicy.fit,
      );
    }
    return image;
  }

  /// Drop [path] from Flutter's image cache (raw [FileImage] + common
  /// [ResizeImage] widths used by shell art).
  ///
  /// Call when a file at a known path is deleted or overwritten. Prefer
  /// unique on-disk names on replace so widgets also get a new provider key.
  static void evictPath(String? path) {
    if (path == null || path.isEmpty) return;
    final fileImage = FileImage(File(path));
    // ignore: discarded_futures — eviction is best-effort; paint must not wait
    fileImage.evict();
    final cache = PaintingBinding.instance.imageCache;
    // Shell decode caps + a few DPR-scaled mid sizes that appear in practice.
    const widths = <int>{
      64, 96, 128, 160, 180, 192, 200, 240, 256, 300, 320, 360, 400, 480, 512,
      540, 640, 720, 800, 960, 1024, 1080, 1280, 1440, 1600, 1920, 2048,
    };
    for (final w in widths) {
      cache.evict(
        ResizeImage(
          fileImage,
          width: w,
          policy: ResizeImagePolicy.fit,
        ),
      );
    }
  }

  /// Warm Flutter's image cache so the next paint has pixels ready.
  ///
  /// Failures (missing file, decode error) are swallowed — callers still
  /// fall through to [errorBuilder] when the widget builds.
  static Future<void> precache(
    BuildContext context,
    String path, {
    int? memCacheWidth,
    int? memCacheHeight,
  }) async {
    if (path.isEmpty) return;
    // Avoid FileImage → PathNotFoundException (Flutter still logs those even
    // when precacheImage's Future completes with an error).
    try {
      if (!File(path).existsSync()) return;
    } catch (_) {
      return;
    }
    try {
      await precacheImage(
        provider(
          path,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
        ),
        context,
      );
    } catch (_) {
      // Missing / unreadable art is fine — UI shows placeholders.
    }
  }

  /// Logical size → cache pixels (clamped so huge covers don't blow memory).
  static int cachePx(double logical, double devicePixelRatio, {int max = 2048}) {
    final px = (logical * devicePixelRatio).round();
    if (px < 1) return 1;
    return px > max ? max : px;
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: provider(
        path,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
      ),
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      filterQuality: filterQuality,
      frameBuilder: fadeIn ? _fadeFrame : null,
      errorBuilder: errorBuilder ??
          (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }

  static Widget _fadeFrame(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded) return child;
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: HomeMotion.artFadeIn,
      curve: HomeMotion.artFadeInCurve,
      child: child,
    );
  }
}
