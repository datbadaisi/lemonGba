import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/library_game.dart';
import '../../infrastructure/library/game_library.dart';
import '../common/shell_art_warmer.dart';
import '../theme/home_tokens.dart';
import 'game_tile.dart';

/// Scrollable library grid with scroll-driven art warm.
class LibraryGridBody extends StatefulWidget {
  const LibraryGridBody({
    super.key,
    required this.library,
    required this.games,
    required this.focusedId,
    required this.onFocus,
    required this.onPlay,
    required this.onLongPress,
  });

  final GameLibrary library;
  final List<LibraryGame> games;
  final String? focusedId;
  final ValueChanged<LibraryGame> onFocus;
  final ValueChanged<LibraryGame> onPlay;
  final ValueChanged<LibraryGame> onLongPress;

  @override
  State<LibraryGridBody> createState() => _LibraryGridBodyState();
}

class _LibraryGridBodyState extends State<LibraryGridBody> {
  final ScrollController _gridScroll = ScrollController();

  /// Last pure layout snapshot used by scroll warm (not mutated mid-build).
  _GridWarmLayout? _warmLayout;

  @override
  void initState() {
    super.initState();
    _gridScroll.addListener(_onGridScroll);
  }

  @override
  void dispose() {
    _gridScroll
      ..removeListener(_onGridScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LibraryGridBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.games, widget.games) ||
        oldWidget.games.length != widget.games.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onGridScroll();
      });
    }
  }

  void _onGridScroll() {
    final layout = _warmLayout;
    if (layout == null || !_gridScroll.hasClients) return;
    if (layout.games.isEmpty) return;
    if (layout.gameRowExtent <= 0) return;

    unawaited(
      ShellArtWarmer.warmFromLibraryGrid(
        context,
        widget.library,
        layout.games,
        colCount: layout.colCount,
        scrollOffset: _gridScroll.offset,
        viewportHeight: layout.viewportH,
        gameRowExtent: layout.gameRowExtent,
      ),
    );
  }

  void _scheduleWarmIfLayoutChanged(_GridWarmLayout next) {
    final prev = _warmLayout;
    final changed =
        prev == null ||
        prev.colCount != next.colCount ||
        prev.viewportH != next.viewportH ||
        (prev.gameRowExtent - next.gameRowExtent).abs() > 0.5 ||
        prev.games.length != next.games.length;

    _warmLayout = next;
    if (!changed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onGridScroll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final games = widget.games;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const pad = HomeSpacing.screenPadH;
        const gap = HomeSpacing.tileGap;
        final colCount = HomeSizes.gridColumnCount(width);
        final tileW = HomeSizes.gridTileSize(width);
        final coverH = tileW;
        final gameRowH = coverH + HomeSizes.tileTitleBlock;
        final gameRowExtent = gameRowH + HomeSpacing.libraryRowGap;
        final rowCount = (games.length + colCount - 1) ~/ colCount;

        // Snapshot for scroll warm after this frame (no field mutation logic
        // mixed into paint — only assign the pure derived layout).
        _scheduleWarmIfLayoutChanged(
          _GridWarmLayout(
            games: games,
            colCount: colCount,
            gameRowExtent: gameRowExtent,
            viewportH: constraints.maxHeight,
          ),
        );

        return ListView.builder(
          controller: _gridScroll,
          padding: const EdgeInsets.fromLTRB(
            pad,
            HomeSpacing.sm,
            pad,
            HomeSpacing.xl,
          ),
          itemCount: rowCount,
          itemBuilder: (context, i) {
            final gameStart = i * colCount;
            final gameCount = (games.length - gameStart).clamp(0, colCount);
            final tiles = <Widget>[];
            for (var k = 0; k < gameCount; k++) {
              if (k > 0) {
                tiles.add(const SizedBox(width: gap));
              }
              final g = games[gameStart + k];
              tiles.add(
                GameTile(
                  game: g,
                  size: coverH,
                  focused: g.id == widget.focusedId,
                  avatarPath: widget.library.avatarAbsolutePath(g),
                  onTap: () => widget.onFocus(g),
                  onDoubleTap: () => widget.onPlay(g),
                  onLongPress: () => widget.onLongPress(g),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: HomeSpacing.libraryRowGap),
              child: SizedBox(
                height: gameRowH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tiles,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GridWarmLayout {
  const _GridWarmLayout({
    required this.games,
    required this.colCount,
    required this.gameRowExtent,
    required this.viewportH,
  });

  final List<LibraryGame> games;
  final int colCount;
  final double gameRowExtent;
  final double viewportH;
}
