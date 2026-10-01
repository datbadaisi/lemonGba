import 'dart:ui';

import 'package:flutter/material.dart';

import '../common/shell_art.dart';
import '../common/shell_file_image.dart';
import '../theme/home_tokens.dart';

/// Full-bleed softly blurred art behind the home shelf (cover, else avatar).
///
/// Meant to sit under [ConsoleChrome] with a transparent chrome fill so the
/// image also paints into the notch / cutout strips.
///
/// Cross-fades only after the next image is [ShellFileImage.precache]'d so
/// the switch never fades into an empty decode frame.
class HomeCoverBackdrop extends StatefulWidget {
  const HomeCoverBackdrop({super.key, this.coverPath});

  final String? coverPath;

  @override
  State<HomeCoverBackdrop> createState() => _HomeCoverBackdropState();
}

class _HomeCoverBackdropState extends State<HomeCoverBackdrop> {
  /// Path currently painted (may lag [widget.coverPath] while warming).
  String? _shownPath;

  /// Bumps on every committed switch so [AnimatedSwitcher] never keeps two
  /// outgoing/incoming children with the same [ValueKey] (focus A→B→A while
  /// the first A is still fading out used to assert "Duplicate keys found").
  int _gen = 0;

  /// Monotonic token so a stale warm-up does not commit after a newer request.
  int _warmToken = 0;

  bool _hasPath(String? p) => p != null && p.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Do not paint until warm completes — avoids first-frame decode pop
    // under the boot fade (base [HomeColors.bg] stays until ready).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestShow(widget.coverPath);
    });
  }

  @override
  void didUpdateWidget(covariant HomeCoverBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverPath != widget.coverPath) {
      _requestShow(widget.coverPath);
    }
  }

  Future<void> _requestShow(String? path) async {
    final token = ++_warmToken;
    final next = _hasPath(path) ? path : null;

    if (next == _shownPath) return;

    if (next != null) {
      final cacheW = ShellArt.backdropCachePx(context);
      await ShellFileImage.precache(
        context,
        next,
        memCacheWidth: cacheW,
      );
    }

    if (!mounted || token != _warmToken) return;
    final stillWanted = _hasPath(widget.coverPath) ? widget.coverPath : null;
    if (next != stillWanted) return;

    setState(() {
      _gen++;
      _shownPath = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final path = _shownPath;
    final hasCover = path != null;
    final switchKey = ValueKey<String>(
      hasCover ? '$_gen|cover:$path' : '$_gen|no-cover',
    );

    final cacheW = ShellArt.backdropCachePx(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: HomeColors.bg),
        AnimatedSwitcher(
          duration: HomeMotion.backdrop,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: _backdropLayout,
          child: hasCover
              ? _SoftCover(
                  key: switchKey,
                  path: path,
                  memCacheWidth: cacheW,
                )
              : SizedBox.expand(key: switchKey),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                HomeColors.artScrim,
                HomeColors.backdropScrimMid,
                HomeColors.backdropScrimBottom,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _backdropLayout(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    final children = <Widget>[];
    final seen = <Key>{};
    final currentKey = currentChild?.key;

    if (currentKey != null) {
      seen.add(currentKey);
    }

    for (final child in previousChildren) {
      final k = child.key;
      if (k != null) {
        if (seen.contains(k)) continue;
        seen.add(k);
      }
      children.add(child);
    }
    if (currentChild != null) {
      children.add(currentChild);
    }

    return Stack(fit: StackFit.expand, children: children);
  }
}

class _SoftCover extends StatelessWidget {
  const _SoftCover({
    super.key,
    required this.path,
    required this.memCacheWidth,
  });

  final String path;
  final int memCacheWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: HomeSizes.backdropBlur,
          sigmaY: HomeSizes.backdropBlur,
          tileMode: TileMode.clamp,
        ),
        child: Transform.scale(
          scale: 1.04,
          child: ShellFileImage(
            path: path,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: memCacheWidth,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: HomeColors.bg),
          ),
        ),
      ),
    );
  }
}
