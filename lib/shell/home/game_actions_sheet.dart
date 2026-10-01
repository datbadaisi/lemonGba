import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/storage/game_pack_port.dart';
import '../../infrastructure/library/game_library.dart';
import '../../models/game_group.dart';
import '../../models/library_game.dart';
import '../common/app_toast.dart';
import '../common/shell_sheet.dart';
import '../theme/home_tokens.dart';
import 'backup_restore_sheet.dart';

/// Shared long-press actions for home shelf + full library grid.
Future<void> showLibraryGameActions({
  required BuildContext context,
  required LibraryGame game,
  required GameLibrary library,
  required GamePackPort packs,
  required VoidCallback onDisplaySettings,
  VoidCallback? onFullImportBusyStart,
  VoidCallback? onFullImportBusyEnd,
  ValueChanged<LibraryGame>? onImportedFull,
  String? removeFromGroupLabel,
  Future<void> Function()? onRemoveFromGroup,
}) {
  return showGameActionsSheet(
    context: context,
    game: game,
    onAddToGroup: () => pickGroupsForGame(
      context: context,
      library: library,
      game: game,
    ),
    onDisplaySettings: onDisplaySettings,
    onBackupRestore: () {
      unawaited(
        showBackupRestoreSheet(
          context: context,
          packs: packs,
          library: library,
          game: game,
          onFullImportBusyStart: onFullImportBusyStart,
          onFullImportBusyEnd: onFullImportBusyEnd,
          onImportedFull: onImportedFull,
        ),
      );
    },
    removeFromGroupLabel: removeFromGroupLabel,
    onRemoveFromGroup: onRemoveFromGroup,
  );
}

/// Long-press actions for a library game (home shelf + full library grid).
///
/// Always shows the sheet. [onAddToGroup] is responsible for empty-group UX
/// (toast) vs the multi-select picker when groups exist.
Future<void> showGameActionsSheet({
  required BuildContext context,
  required LibraryGame game,
  required VoidCallback onAddToGroup,
  required VoidCallback onDisplaySettings,
  VoidCallback? onBackupRestore,
  String? removeFromGroupLabel,
  Future<void> Function()? onRemoveFromGroup,
}) {
  return showShellModalSheet<void>(
    context: context,
    // Grow to content — default half-sheet max (~200px) overflows action rows.
    isScrollControlled: true,
    builder: (ctx) {
      return ShellSheetActionColumn(
        header: ShellSheetTitleBar(title: game.title),
        children: [
          ShellSheetAction(
            icon: HugeIcons.strokeRoundedFolderAdd,
            label: 'Add to group…',
            onTap: () {
              Navigator.pop(ctx);
              onAddToGroup();
            },
          ),
          if (removeFromGroupLabel != null && onRemoveFromGroup != null)
            ShellSheetAction(
              icon: HugeIcons.strokeRoundedFolderRemove,
              label: removeFromGroupLabel,
              color: HomeColors.missing,
              onTap: () {
                Navigator.pop(ctx);
                unawaited(onRemoveFromGroup());
              },
            ),
          ShellSheetAction(
            icon: HugeIcons.strokeRoundedPaintBoard,
            label: 'Display settings',
            onTap: () {
              Navigator.pop(ctx);
              onDisplaySettings();
            },
          ),
          if (onBackupRestore != null)
            ShellSheetAction(
              icon: HugeIcons.strokeRoundedFloppyDisk,
              label: 'Backup & restore…',
              onTap: () {
                Navigator.pop(ctx);
                onBackupRestore();
              },
            ),
          const SizedBox(height: HomeSpacing.sm),
        ],
      );
    },
  );
}

/// Multi-select which groups contain [game].
///
/// When the library has no groups yet, only shows a toast (does not open a
/// create-group flow — that lives on the library header).
Future<void> pickGroupsForGame({
  required BuildContext context,
  required GameLibrary library,
  required LibraryGame game,
}) async {
  final groups = library.groups;
  if (groups.isEmpty) {
    AppToast.error(context, 'No groups yet');
    return;
  }

  final selected = await showShellModalSheet<Set<String>>(
    context: context,
    // Content sizes to rows; ShellSheetScrollBody scrolls only if overflow.
    isScrollControlled: true,
    builder: (ctx) {
      return _PickGroupsSheet(
        gameTitle: game.title,
        groups: groups,
        initiallySelected: {
          for (final g in groups)
            if (g.gameIds.contains(game.id)) g.id,
        },
      );
    },
  );

  if (selected == null || !context.mounted) return;
  // One atomic persist for all membership changes.
  await library.setGroupsForGame(game.id, selected);
  if (context.mounted) AppToast.success(context, 'Groups updated');
}

/// Multi-select groups for one game — chrome matches game long-press sheet.
class _PickGroupsSheet extends StatefulWidget {
  const _PickGroupsSheet({
    required this.gameTitle,
    required this.groups,
    required this.initiallySelected,
  });

  final String gameTitle;
  final List<GameGroup> groups;
  final Set<String> initiallySelected;

  @override
  State<_PickGroupsSheet> createState() => _PickGroupsSheetState();
}

class _PickGroupsSheetState extends State<_PickGroupsSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initiallySelected);
  }

  void _toggle(String id, bool on) {
    setState(() {
      if (on) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Same content-sized body as short action sheets (no full-height stretch).
    return ShellSheetActionColumn(
      header: ShellSheetTitleBar(
        title: 'Groups · ${widget.gameTitle}',
        trailing: TextButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text(
            'Done',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: HomeSizes.sheetActionSize,
              color: HomeColors.lemon,
            ),
          ),
        ),
      ),
      children: [
        for (final g in widget.groups)
          ShellSheetCheckRow(
            label: g.name,
            selected: _selected.contains(g.id),
            onChanged: (on) => _toggle(g.id, on),
          ),
        const SizedBox(height: HomeSpacing.sm),
      ],
    );
  }
}
