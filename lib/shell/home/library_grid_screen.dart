import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/entitlements/free_limits.dart';
import '../../core/storage/game_pack_port.dart';
import '../../models/game_group.dart';
import '../../models/library_game.dart';
import '../../infrastructure/entitlements/pro_access.dart';
import '../../infrastructure/library/game_library.dart';
import '../common/app_toast.dart';
import '../common/console_chrome.dart';
import '../common/shell_art_warmer.dart';
import '../common/shell_confirm_dialog.dart';
import '../theme/home_tokens.dart';
import 'game_actions_sheet.dart';
import 'library_empty_body.dart';
import 'library_grid_body.dart';
import 'library_group_sheets.dart';
import 'library_header.dart';

/// Full library grid — same recent-first order as the home shelf.
///
/// Supports user **groups**: create folders, add titles, then filter the grid
/// by group for quick access when the library is large.
///
/// Focus is absolute via [focusedId] / [onFocusedIdChanged] only — no local
/// mirror; parent ([HomeShelfController]) is the single source of truth.
class LibraryGridScreen extends StatefulWidget {
  const LibraryGridScreen({
    super.key,
    required this.library,
    required this.packs,
    required this.pro,
    required this.onPlay,
    required this.onFocusedIdChanged,
    required this.onOpenDisplaySettings,
    this.focusedId,
    this.onPackBusyStart,
    this.onPackBusyEnd,
    this.onImportedFull,
  });

  final GameLibrary library;
  final GamePackPort packs;
  final ProAccess pro;
  final ValueChanged<LibraryGame> onPlay;

  /// Absolute focus update (null = clear). Parent applies the same value.
  final ValueChanged<String?> onFocusedIdChanged;
  final ValueChanged<LibraryGame> onOpenDisplaySettings;
  final String? focusedId;

  /// Shared home busy gate for full-pack import from long-press backup.
  final VoidCallback? onPackBusyStart;
  final VoidCallback? onPackBusyEnd;
  final ValueChanged<LibraryGame>? onImportedFull;

  @override
  State<LibraryGridScreen> createState() => _LibraryGridScreenState();
}

class _LibraryGridScreenState extends State<LibraryGridScreen> {
  /// `null` = All games; otherwise a [GameGroup.id].
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    widget.library.addListener(_onLibraryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ShellArtWarmer.warmBootPage(context, widget.library));
      ShellArtWarmer.scheduleBackgroundFill(context, widget.library);
    });
  }

  @override
  void dispose() {
    widget.library.removeListener(_onLibraryChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LibraryGridScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.library != widget.library) {
      oldWidget.library.removeListener(_onLibraryChanged);
      widget.library.addListener(_onLibraryChanged);
    }
  }

  void _onLibraryChanged() {
    final id = _selectedGroupId;
    if (id != null && widget.library.groupById(id) == null) {
      if (mounted) setState(() => _selectedGroupId = null);
    }
  }

  /// Report absolute toggle to parent; parent owns focus state.
  void _focusGame(LibraryGame game) {
    final next = widget.focusedId == game.id ? null : game.id;
    widget.onFocusedIdChanged(next);
  }

  List<LibraryGame> _visibleGames() {
    final id = _selectedGroupId;
    if (id == null) return widget.library.gamesByRecent;
    return widget.library.gamesInGroup(id);
  }

  GameGroup? get _selectedGroup {
    final id = _selectedGroupId;
    if (id == null) return null;
    return widget.library.groupById(id);
  }

  Future<void> _createGroup() async {
    if (!widget.library.canCreateGroup()) {
      AppToast.error(context, FreeTierMessages.groups);
      return;
    }
    final name = await promptGroupName(context: context, title: 'New group');
    if (name == null || name.isEmpty) return;
    try {
      final group = await widget.library.createGroup(name);
      if (!mounted) return;
      setState(() => _selectedGroupId = group.id);
      AppToast.success(context, 'Created “${group.name}”');
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    }
  }

  Future<void> _renameGroup(GameGroup group) async {
    final name = await promptGroupName(
      context: context,
      title: 'Rename group',
      initial: group.name,
    );
    if (name == null || name.isEmpty || name == group.name) return;
    try {
      await widget.library.renameGroup(group.id, name);
      if (mounted) AppToast.success(context, 'Renamed to “$name”');
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    }
  }

  Future<void> _deleteGroup(GameGroup group) async {
    final ok = await showShellConfirmDialog(
      context,
      title: 'Delete group?',
      message: '“${group.name}” will be removed. Games stay in your library.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok != true) return;
    await widget.library.deleteGroup(group.id);
    if (!mounted) return;
    if (_selectedGroupId == group.id) {
      setState(() => _selectedGroupId = null);
    }
    AppToast.success(context, 'Deleted “${group.name}”');
  }

  Future<void> _showGroupActions(GameGroup group) {
    return showGroupActionsSheet(
      context: context,
      group: group,
      onRename: () => _renameGroup(group),
      onDelete: () => _deleteGroup(group),
    );
  }

  Future<void> _addGamesToSelectedGroup() async {
    final group = _selectedGroup;
    if (group == null) return;

    final all = widget.library.gamesByRecent;
    if (all.isEmpty) {
      AppToast.error(context, 'No games in library yet');
      return;
    }

    final selected = await pickGamesForGroup(
      context: context,
      title: 'Add to “${group.name}”',
      games: all,
      initiallySelected: group.gameIds.toSet(),
      avatarPathOf: widget.library.avatarAbsolutePath,
    );

    if (selected == null || !mounted) return;
    try {
      // Domain preserves existing order and appends new ids.
      await widget.library.setGroupGames(group.id, selected.toList());
      if (mounted) {
        AppToast.success(context, 'Updated “${group.name}”');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    }
  }

  Future<void> _onGameLongPress(LibraryGame game) async {
    final inSelectedGroup =
        _selectedGroupId != null &&
        widget.library.isGameInGroup(_selectedGroupId!, game.id);

    await showLibraryGameActions(
      context: context,
      game: game,
      library: widget.library,
      packs: widget.packs,
      onDisplaySettings: () => widget.onOpenDisplaySettings(game),
      onFullImportBusyStart: widget.onPackBusyStart,
      onFullImportBusyEnd: widget.onPackBusyEnd,
      onImportedFull: widget.onImportedFull,
      removeFromGroupLabel: inSelectedGroup
          ? 'Remove from “${_selectedGroup?.name ?? 'group'}”'
          : null,
      onRemoveFromGroup: inSelectedGroup
          ? () async {
              final gid = _selectedGroupId;
              if (gid == null) return;
              await widget.library.removeGameFromGroup(gid, game.id);
              if (mounted) {
                AppToast.success(context, 'Removed from group');
              }
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.bg,
      // Modal sheets own IME padding (e.g. new-group name). If this scaffold
      // also shrinks for viewInsets, landscape height collapses under the
      // header and the yellow debug overflow stripe flashes while sheet +
      // keyboard dismiss. Keep false: any future in-body field on this screen
      // must pad for the IME itself rather than re-enabling this flag.
      resizeToAvoidBottomInset: false,
      body: ConsoleChrome(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.library, widget.pro]),
          builder: (context, _) {
            final viewingGroup = _selectedGroupId != null;
            final selectedGroup = _selectedGroup;
            final games = _visibleGames();
            final groups = widget.library.groups;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LibraryHeader(
                  groups: groups,
                  selectedGroupId: _selectedGroupId,
                  onBack: () => Navigator.of(context).maybePop(),
                  onSelectAll: () {
                    setState(() => _selectedGroupId = null);
                  },
                  onSelectGroup: (id) {
                    setState(() => _selectedGroupId = id);
                  },
                  onCreateGroup: _createGroup,
                  onAddGames: _addGamesToSelectedGroup,
                  onGroupOptions: selectedGroup == null
                      ? null
                      : () => _showGroupActions(selectedGroup),
                ),
                Expanded(
                  child: games.isEmpty
                      ? EmptyLibraryBody(
                          isGroup: viewingGroup,
                          groupName: selectedGroup?.name,
                        )
                      : LibraryGridBody(
                          library: widget.library,
                          games: games,
                          focusedId: widget.focusedId,
                          onFocus: _focusGame,
                          onPlay: widget.onPlay,
                          onLongPress: _onGameLongPress,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
