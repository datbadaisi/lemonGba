import 'dart:async';

import 'package:flutter/material.dart';

import '../../infrastructure/emulator/play_session_factory.dart';
import '../../infrastructure/entitlements/pro_access.dart';
import '../../infrastructure/entitlements/pro_billing.dart';
import '../../infrastructure/native/gba_core.dart';
import '../../core/storage/game_pack_port.dart';
import '../../models/library_game.dart';
import '../../infrastructure/library/game_library.dart';
import '../../infrastructure/play/play_layout_store.dart';
import '../../infrastructure/storage/save_paths.dart';
import '../play/game_screen.dart';
import '../theme/home_tokens.dart';
import '../common/dock_chiptune.dart';
import 'game_display_settings_screen.dart';
import 'game_pack_ui.dart';
import 'library_grid_screen.dart';
import 'multi_backup_screen.dart';
import 'settings_screen.dart';
import '../common/app_toast.dart';
import '../common/console_chrome.dart';
import '../common/shell_confirm_dialog.dart';
import '../common/shell_art_warmer.dart';
import 'game_actions_sheet.dart';
import 'game_row.dart';
import 'game_tile.dart';
import 'home_cover_backdrop.dart';
import 'home_empty_shelf.dart';
import 'home_shelf_controller.dart';
import 'home_shelf_metrics.dart';
import 'home_top_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.core,
    required this.paths,
    required this.library,
    required this.packs,
    required this.pro,
    required this.billing,
    required this.playLayout,
  });

  final GbaCore core;
  final SavePaths paths;
  final GameLibrary library;
  final GamePackPort packs;
  final ProAccess pro;
  final ProBilling billing;
  final PlayLayoutStore playLayout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const int _homeShelfLimit = 5;

  final HomeShelfController _shelf = HomeShelfController();
  final ScrollController _shelfScroll = ScrollController();

  late final AnimationController _bootReveal;
  late final Animation<double> _bootBackdropFade;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _shelfFade;
  late final Animation<Offset> _shelfSlide;

  GameLibrary get _library => widget.library;

  late final PlaySessionFactory _playSessions = PlaySessionFactory(
    core: widget.core,
    paths: widget.paths,
  );

  @override
  void initState() {
    super.initState();
    unawaited(AppSfx.preload());

    _bootReveal = AnimationController(
      vsync: this,
      duration: HomeMotion.bootReveal,
    );
    _bootBackdropFade = CurvedAnimation(
      parent: _bootReveal,
      curve: HomeMotion.bootRevealBackdropCurve,
    );
    _headerFade = CurvedAnimation(
      parent: _bootReveal,
      curve: HomeMotion.bootRevealHeaderFade,
    );
    _headerSlide =
        Tween<Offset>(
          begin: const Offset(0, HomeMotion.bootRevealHeaderFromY),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _bootReveal,
            curve: HomeMotion.bootRevealHeaderSlide,
          ),
        );
    _shelfFade = CurvedAnimation(
      parent: _bootReveal,
      curve: HomeMotion.bootRevealShelfFade,
    );
    _shelfSlide =
        Tween<Offset>(
          begin: const Offset(HomeMotion.bootRevealShelfFromX, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _bootReveal,
            curve: HomeMotion.bootRevealShelfSlide,
          ),
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootReveal.forward();
      _warmShelfArt();
    });
    _library.addListener(_onLibraryChanged);
  }

  void _onLibraryChanged() {
    _shelf.dropFocusIfMissing((id) => _library.byId(id) != null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _warmShelfArt();
    });
  }

  void _warmShelfArt() {
    if (!mounted) return;
    unawaited(
      ShellArtWarmer.warmShelf(context, _library, limit: _homeShelfLimit),
    );
    unawaited(
      Future<void>.delayed(HomeMotion.bootReveal, () {
        if (!mounted) return;
        ShellArtWarmer.scheduleBackgroundFill(context, _library);
      }),
    );
  }

  @override
  void dispose() {
    _library.removeListener(_onLibraryChanged);
    _bootReveal.dispose();
    _shelfScroll.dispose();
    _shelf.dispose();
    super.dispose();
  }

  void _sfxTap() => AppSfx.playTap();

  /// After play / add, data order puts that game first — also reset the shelf
  /// viewport so ListView does not stay scrolled at the old offset.
  void _scrollShelfToStart({bool animated = true}) {
    bool needsScroll() {
      if (!_shelfScroll.hasClients) return false;
      final position = _shelfScroll.position;
      if (!position.hasContentDimensions) return false;
      return position.pixels > 0.5;
    }

    void snapToStart() {
      if (!mounted || !needsScroll()) return;
      _shelfScroll.jumpTo(0);
    }

    void animateToStart() {
      if (!mounted || !needsScroll()) return;
      unawaited(
        _shelfScroll.animateTo(
          0,
          duration: HomeMotion.shelfScrollToStart,
          curve: HomeMotion.shelfScrollToStartCurve,
        ),
      );
    }

    void run() {
      if (animated) {
        animateToStart();
      } else {
        snapToStart();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_shelfScroll.hasClients) {
        run();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        run();
      });
    });
  }

  LibraryGame? get _focusedGame {
    final id = _shelf.focusedId;
    if (id == null) return null;
    return _library.byId(id);
  }

  LibraryGame? get _backdropGame {
    final focused = _focusedGame;
    if (focused != null) return focused;
    final recent = _library.gamesByRecent;
    if (recent.isEmpty) return null;
    return recent.first;
  }

  void _toastSuccess(String message) {
    if (!mounted) return;
    AppToast.success(context, message);
  }

  void _toastError(String message) {
    if (!mounted) return;
    AppToast.error(context, message);
  }

  void _focusGame(LibraryGame game) {
    _sfxTap();
    _shelf.toggleFocus(game.id);
  }

  void _clearFocus() {
    if (_shelf.focusedId == null) return;
    _sfxTap();
    _shelf.clearFocus();
  }

  void _runImportProgress(String gameId) {
    _shelf.beginImportProgress(gameId);
    _scrollShelfToStart(animated: true);
    Future<void>.delayed(HomeMotion.importProgress, () {
      if (!mounted) return;
      _shelf.endImportProgress(gameId);
    });
  }

  void _setPackBusy(bool busy) {
    if (mounted) _shelf.setBusy(busy);
  }

  Future<void> _addGame() async {
    if (_shelf.busy) return;
    _sfxTap();

    _shelf.setBusy(true);
    LibraryGame? game;
    try {
      game = await addGameFromPicker(
        context: context,
        packs: widget.packs,
        library: _library,
        onWorkStart: (message) {
          if (!mounted) return;
          AppProgressToast.show(context, message: message);
        },
      );
    } catch (e) {
      AppProgressToast.dismiss();
      if (mounted) _toastError(e.toString());
    } finally {
      if (mounted) _shelf.setBusy(false);
    }

    if (!mounted) return;
    AppProgressToast.dismiss();
    if (game == null) return;
    _runImportProgress(game.id);
  }

  Future<void> _playGame(LibraryGame game) async {
    if (game.missing) {
      _toastError('ROM file missing. Remove and add again.');
      return;
    }
    _sfxTap();

    final romPath = _library.romPathOf(game);
    final session = _playSessions.open(romPath: romPath, gameId: game.id);
    final result = await Navigator.of(context).push<GameSessionResult>(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          controller: session.controller,
          renderer: session.renderer,
          playLayout: widget.playLayout,
          onCheckpointPlayTime: (delta) => _library.addPlayTime(game.id, delta),
        ),
      ),
    );

    if (!mounted) return;
    await _library.touchLastPlayed(game.id);
    final played = result?.playDuration ?? Duration.zero;
    if (played > Duration.zero) {
      await _library.addPlayTime(game.id, played);
    }
    final title = result?.headerTitle;
    if (title != null && title.isNotEmpty) {
      await _library.updateHeaderTitle(game.id, title);
    }
    if (!mounted) return;
    _shelf.setFocusedId(game.id);
    _scrollShelfToStart();
  }

  void _openFullLibrary() {
    _sfxTap();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListenableBuilder(
          listenable: _shelf,
          builder: (context, _) {
            return LibraryGridScreen(
              library: _library,
              packs: widget.packs,
              pro: widget.pro,
              focusedId: _shelf.focusedId,
              onFocusedIdChanged: (id) {
                _sfxTap();
                _shelf.setFocusedId(id);
              },
              onPlay: _playGame,
              onOpenDisplaySettings: _openDisplaySettings,
              onPackBusyStart: () => _setPackBusy(true),
              onPackBusyEnd: () => _setPackBusy(false),
              onImportedFull: (g) {
                if (!mounted) return;
                _runImportProgress(g.id);
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openDisplaySettings(LibraryGame game) async {
    _sfxTap();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameDisplaySettingsScreen(
          library: _library,
          gameId: game.id,
          onRemove: (g) async {
            await _confirmRemove(g);
          },
        ),
      ),
    );
    if (!mounted) return;
    _shelf.dropFocusIfMissing((id) => _library.byId(id) != null);
  }

  Future<void> _onGameLongPress(LibraryGame game) async {
    _sfxTap();
    await showLibraryGameActions(
      context: context,
      game: game,
      library: _library,
      packs: widget.packs,
      onDisplaySettings: () => _openDisplaySettings(game),
      onFullImportBusyStart: () => _setPackBusy(true),
      onFullImportBusyEnd: () => _setPackBusy(false),
      onImportedFull: (g) {
        if (!mounted) return;
        _runImportProgress(g.id);
      },
    );
  }

  Future<bool> _confirmRemove(LibraryGame game) async {
    final confirmed = await showShellConfirmDialog(
      context,
      title: 'Delete game?',
      message:
          '“${game.title}” will be removed from the shelf, and this app’s '
          'ROM copy, cartridge save, and savestates will be erased.\n\n'
          'Your original ROM file outside the app is not touched.',
      confirmLabel: 'Delete all',
      destructive: true,
    );

    if (confirmed != true) return false;
    final title = game.title;
    await _library.remove(game.id);
    if (_shelf.focusedId == game.id) {
      _shelf.clearFocus();
    }
    _shelf.clearImportIf(game.id);
    _toastSuccess('Deleted “$title” and all local play data');
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final library = _library;

    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: ListenableBuilder(
        listenable: Listenable.merge([library, _shelf]),
        builder: (context, _) {
          final backdrop = _backdropGame;
          final artPath = backdrop == null
              ? null
              : library.backdropAbsolutePath(backdrop);
          final busy = _shelf.busy;

          return Stack(
            fit: StackFit.expand,
            children: [
              FadeTransition(
                opacity: _bootBackdropFade,
                child: HomeCoverBackdrop(coverPath: artPath),
              ),
              ClipRect(
                child: ConsoleChrome(
                  bottom: false,
                  backgroundColor: Colors.transparent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeTransition(
                        opacity: _headerFade,
                        child: SlideTransition(
                          position: _headerSlide,
                          child: AnimatedBuilder(
                            animation: widget.pro,
                            builder: (context, _) {
                              return HomeTopBar(
                                busy: busy,
                                multiBackupLocked: !widget.pro.isPro,
                                onAdd: busy ? null : _addGame,
                                onMultiBackup: busy
                                    ? null
                                    : () {
                                        _sfxTap();
                                        // Free users can open the screen to
                                        // preview; export/import stay Pro-gated.
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => MultiBackupScreen(
                                              packs: widget.packs,
                                              library: widget.library,
                                            ),
                                          ),
                                        );
                                      },
                                onSettings: () {
                                  _sfxTap();
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SettingsScreen(
                                        coreVersion: widget.core.coreVersion,
                                        pro: widget.pro,
                                        billing: widget.billing,
                                        playLayout: widget.playLayout,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: FadeTransition(
                          opacity: _shelfFade,
                          child: SlideTransition(
                            position: _shelfSlide,
                            child: AnimatedBuilder(
                              animation: widget.pro,
                              builder: (context, _) {
                                final all = library.gamesByRecent;
                                if (all.isEmpty) {
                                  return HomeEmptyShelf(
                                    busy: busy,
                                    onAdd: _addGame,
                                  );
                                }
                                return GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: _clearFocus,
                                  child: _HomeShelf(
                                    library: library,
                                    shelfLimit: _homeShelfLimit,
                                    focusedId: _shelf.focusedId,
                                    importingId: _shelf.importingId,
                                    scrollController: _shelfScroll,
                                    onFocus: _focusGame,
                                    onPlay: _playGame,
                                    onLongPress: _onGameLongPress,
                                    onOpenLibrary: _openFullLibrary,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeShelf extends StatelessWidget {
  const _HomeShelf({
    required this.library,
    required this.shelfLimit,
    required this.focusedId,
    required this.importingId,
    required this.scrollController,
    required this.onFocus,
    required this.onPlay,
    required this.onLongPress,
    required this.onOpenLibrary,
  });

  final GameLibrary library;
  final int shelfLimit;
  final String? focusedId;
  final String? importingId;
  final ScrollController scrollController;
  final ValueChanged<LibraryGame> onFocus;
  final ValueChanged<LibraryGame> onPlay;
  final ValueChanged<LibraryGame> onLongPress;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final all = library.gamesByRecent;
    final shelf = library.homeShelf(limit: shelfLimit);
    LibraryGame? focusedGame;
    if (focusedId != null) {
      for (final g in shelf) {
        if (g.id == focusedId) {
          focusedGame = g;
          break;
        }
      }
      // Focus may still be a library-only title (not on the home strip).
      focusedGame ??= library.byId(focusedId!);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = HomeShelfMetrics.resolve(constraints.maxHeight);
        final tileSize = metrics.tileSize;

        final children = <Widget>[];
        for (final g in shelf) {
          children.add(
            GameTile(
              game: g,
              size: tileSize,
              focused: g.id == focusedId,
              loading: g.id == importingId,
              avatarPath: library.avatarAbsolutePath(g),
              onTap: () => onFocus(g),
              onDoubleTap: () => onPlay(g),
              onLongPress: () => onLongPress(g),
            ),
          );
        }
        children.add(
          MoreGamesTile(
            size: tileSize,
            totalCount: all.length,
            onTap: onOpenLibrary,
          ),
        );

        // Play-time badge under the whole shelf list, screen-centered.
        final badgeLabel = (focusedGame != null && focusedId != importingId)
            ? focusedGame.playTimeLabel
            : null;

        return Align(
          alignment: HomeShelfMetrics.shelfAlign,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameRow(
                tileHeight: tileSize,
                controller: scrollController,
                children: children,
              ),
              SizedBox(
                height: HomeSizes.playTimeBadgeSlot,
                width: double.infinity,
                child: badgeLabel == null
                    ? null
                    : Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: HomeSizes.playTimeBadgeShelfGap,
                          ),
                          child: PlayTimeBadge(label: badgeLabel),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
