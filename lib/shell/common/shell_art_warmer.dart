import 'dart:async';

import 'package:flutter/material.dart';

import '../../infrastructure/library/game_library.dart';
import '../../models/library_game.dart';
import '../theme/home_tokens.dart';
import 'shell_art.dart';
import 'shell_file_image.dart';

/// Priority + chunked avatar warmer for large libraries (100+ titles).
///
/// Architecture:
/// - **Boot / first page**: small parallel batch ([HomeSizes.artWarmBootBatch]).
/// - **Visible window**: high priority when the library grid scrolls.
/// - **Background**: remaining games in small chunks with UI yields.
/// - **Dedup**: path+memW keys — never re-decode the same cache entry twice
///   in one session (unless [invalidatePath]).
///
/// Paint still uses [ShellArt.avatarMemCacheWidth] so warm keys == paint keys.
abstract final class ShellArtWarmer {
  static final Set<String> _done = <String>{};
  static final Set<String> _inflight = <String>{};

  /// Bumped to cancel an in-flight background fill.
  static int _bgGen = 0;

  static String _avatarKey(String path, int memW) => 'av:$memW:$path';

  static String _backdropKey(String path, int memW) => 'bd:$memW:$path';

  /// Drop a path from the warm set (after replace/delete art).
  static void invalidatePath(String? path) {
    if (path == null || path.isEmpty) return;
    _done.removeWhere((k) => k.endsWith(':$path'));
  }

  static void invalidateAll() {
    _done.clear();
    _bgGen++;
  }

  /// First-page warm for dock / library open (awaits completion).
  static Future<void> warmBootPage(BuildContext context, GameLibrary library) {
    return warmAvatars(
      context,
      library,
      library.gamesByRecent.take(HomeSizes.artWarmBootBatch),
    );
  }

  /// Home shelf tiles (+ optional backdrop banners).
  static Future<void> warmShelf(
    BuildContext context,
    GameLibrary library, {
    int limit = 5,
  }) async {
    final shelf = library.homeShelf(limit: limit);
    await warmAvatars(context, library, shelf);
    if (!context.mounted) return;
    final bdW = ShellArt.backdropCachePx(context);
    await Future.wait([
      for (final g in shelf) _warmBackdrop(context, library, g, bdW),
    ]);
  }

  /// Warm avatars in and near the visible library grid rows.
  static Future<void> warmFromLibraryGrid(
    BuildContext context,
    GameLibrary library,
    List<LibraryGame> ordered, {
    required int colCount,
    required double scrollOffset,
    required double viewportHeight,
    required double gameRowExtent,
    int lookaheadRows = HomeSizes.artWarmScrollLookaheadRows,
  }) {
    if (ordered.isEmpty || colCount < 1 || gameRowExtent <= 0) {
      return Future<void>.value();
    }

    final lookahead = gameRowExtent * lookaheadRows;
    final viewTop = scrollOffset - lookahead;
    final viewBottom = scrollOffset + viewportHeight + lookahead;

    final seen = <String>{};
    final toWarm = <LibraryGame>[];
    final rowCount = (ordered.length + colCount - 1) ~/ colCount;
    for (var row = 0; row < rowCount; row++) {
      final y = row * gameRowExtent;
      final rowBottom = y + gameRowExtent;
      final visible = rowBottom > viewTop && y < viewBottom;
      if (visible) {
        for (var k = 0; k < colCount; k++) {
          final gi = row * colCount + k;
          if (gi >= ordered.length) break;
          final g = ordered[gi];
          if (seen.add(g.id)) toWarm.add(g);
        }
      }
      if (rowBottom > viewBottom && toWarm.isNotEmpty) break;
    }
    if (toWarm.isEmpty) return Future<void>.value();
    return warmAvatars(context, library, toWarm);
  }

  /// Queue remaining library avatars in background chunks (non-blocking).
  ///
  /// Cancels any previous background run. Safe to call after home entrance.
  static void scheduleBackgroundFill(
    BuildContext context,
    GameLibrary library,
  ) {
    final gen = ++_bgGen;
    unawaited(_backgroundFill(context, library, gen));
  }

  static Future<void> _backgroundFill(
    BuildContext context,
    GameLibrary library,
    int gen,
  ) async {
    // Yield once so the caller’s frame (boot reveal) paints first.
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted || gen != _bgGen) return;

    final memW = ShellArt.avatarMemCacheWidth(context);
    final pending = <String>[];
    for (final g in library.gamesByRecent) {
      final p = library.avatarAbsolutePath(g);
      if (p == null || p.isEmpty) continue;
      final k = _avatarKey(p, memW);
      if (_done.contains(k) || _inflight.contains(k)) continue;
      pending.add(p);
    }
    if (pending.isEmpty) return;

    final chunk = HomeSizes.artWarmChunk;
    final gap = HomeSizes.artWarmChunkGap;
    for (var i = 0; i < pending.length; i += chunk) {
      if (!context.mounted || gen != _bgGen) return;
      final end = i + chunk < pending.length ? i + chunk : pending.length;
      final slice = pending.sublist(i, end);
      await Future.wait([
        for (final path in slice) _precacheAvatarPath(context, path, memW),
      ]);
      if (end < pending.length) {
        await Future<void>.delayed(gap);
      }
    }
  }

  /// Parallel warm for a small set of games (skips already done).
  static Future<void> warmAvatars(
    BuildContext context,
    GameLibrary library,
    Iterable<LibraryGame> games,
  ) async {
    if (!context.mounted) return;
    ShellArt.configureImageCache();
    final memW = ShellArt.avatarMemCacheWidth(context);
    final jobs = <Future<void>>[];
    for (final g in games) {
      final p = library.avatarAbsolutePath(g);
      if (p == null || p.isEmpty) continue;
      jobs.add(_precacheAvatarPath(context, p, memW));
    }
    if (jobs.isEmpty) return;
    await Future.wait(jobs);
  }

  static Future<void> _precacheAvatarPath(
    BuildContext context,
    String path,
    int memW,
  ) async {
    final k = _avatarKey(path, memW);
    if (_done.contains(k)) return;
    if (_inflight.contains(k)) {
      while (_inflight.contains(k) && context.mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
      return;
    }
    _inflight.add(k);
    try {
      if (!context.mounted) return;
      await ShellFileImage.precache(context, path, memCacheWidth: memW);
      _done.add(k);
    } catch (_) {
      // Missing file — leave out of _done so a later import can retry.
    } finally {
      _inflight.remove(k);
    }
  }

  static Future<void> _warmBackdrop(
    BuildContext context,
    GameLibrary library,
    LibraryGame game,
    int memW,
  ) async {
    final path = library.backdropAbsolutePath(game);
    if (path == null || path.isEmpty) return;
    final k = _backdropKey(path, memW);
    if (_done.contains(k) || _inflight.contains(k)) return;
    _inflight.add(k);
    try {
      if (!context.mounted) return;
      await ShellFileImage.precache(context, path, memCacheWidth: memW);
      _done.add(k);
    } catch (_) {
    } finally {
      _inflight.remove(k);
    }
  }
}
