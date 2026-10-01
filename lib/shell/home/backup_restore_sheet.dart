import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/storage/game_pack_port.dart';
import '../../infrastructure/library/game_library.dart';
import '../../models/library_game.dart';
import '../common/app_toast.dart';
import '../common/shell_confirm_dialog.dart';
import '../common/shell_sheet.dart';
import '../theme/home_tokens.dart';
import 'game_pack_ui.dart';

/// Per-game backup / restore sub-sheet (opened from long-press actions).
Future<void> showBackupRestoreSheet({
  required BuildContext context,
  required GamePackPort packs,
  required GameLibrary library,
  required LibraryGame game,
  ValueChanged<LibraryGame>? onImportedFull,
  VoidCallback? onFullImportBusyStart,
  VoidCallback? onFullImportBusyEnd,
}) {
  return showShellModalSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return _BackupRestoreSheet(
        packs: packs,
        library: library,
        game: game,
        onImportedFull: onImportedFull,
        onFullImportBusyStart: onFullImportBusyStart,
        onFullImportBusyEnd: onFullImportBusyEnd,
      );
    },
  );
}

class _BackupRestoreSheet extends StatefulWidget {
  const _BackupRestoreSheet({
    required this.packs,
    required this.library,
    required this.game,
    this.onImportedFull,
    this.onFullImportBusyStart,
    this.onFullImportBusyEnd,
  });

  final GamePackPort packs;
  final GameLibrary library;
  final LibraryGame game;
  final ValueChanged<LibraryGame>? onImportedFull;
  final VoidCallback? onFullImportBusyStart;
  final VoidCallback? onFullImportBusyEnd;

  @override
  State<_BackupRestoreSheet> createState() => _BackupRestoreSheetState();
}

class _BackupRestoreSheetState extends State<_BackupRestoreSheet> {
  bool _busy = false;

  Future<void> _exportSave() {
    return runGamePackExport(
      context: context,
      busy: _busy,
      setBusy: (v) => setState(() => _busy = v),
      workingMessage: 'Exporting save pack…',
      successMessage: 'Save pack exported',
      export: () => widget.packs.exportSavePack(
        gameId: widget.game.id,
        titleForFileName: widget.game.title,
      ),
    );
  }

  Future<void> _exportFull() {
    return runGamePackExport(
      context: context,
      busy: _busy,
      setBusy: (v) => setState(() => _busy = v),
      workingMessage: 'Exporting full pack…',
      successMessage: 'Full pack exported',
      export: () => widget.packs.exportFullPack(
        gameId: widget.game.id,
        titleForFileName: widget.game.title,
      ),
    );
  }

  Future<void> _importSave() async {
    if (_busy) return;
    final path = await pickLemonPackPath();
    if (path == null || !mounted) return;

    try {
      final inspected = await widget.packs.inspect(path);
      if (!mounted) return;
      if (inspected is! SinglePackInspect) {
        AppToast.error(context, 'Expected a save pack');
        return;
      }
      final info = inspected.info;
      if (info.kind != GamePackKind.saves) {
        AppToast.error(context, 'Expected a save pack');
        return;
      }
      if (info.gameId != widget.game.id) {
        AppToast.error(context, 'This pack belongs to a different game');
        return;
      }

      final exported = info.exportedAt.toLocal().toString().split('.').first;
      final ok = await showShellConfirmDialog(
        context,
        title: 'Restore progress?',
        message:
            'This replaces cartridge save and all savestates for '
            '“${widget.game.title}” with the pack from $exported.',
        confirmLabel: 'Restore',
        destructive: true,
      );
      if (ok != true || !mounted) return;

      setState(() => _busy = true);
      AppProgressToast.show(context, message: 'Restoring progress…');
      try {
        await widget.packs.importSavePack(
          zipPath: path,
          expectedGameId: widget.game.id,
        );
        if (mounted) {
          Navigator.pop(context);
          AppProgressToast.completeSuccess(context, 'Progress restored');
        } else {
          AppProgressToast.dismiss();
        }
      } on GamePackException catch (e) {
        if (mounted) {
          AppProgressToast.completeError(context, toastForGamePackError(e));
        } else {
          AppProgressToast.dismiss();
        }
      } catch (_) {
        if (mounted) {
          AppProgressToast.completeError(context, 'Could not import pack');
        } else {
          AppProgressToast.dismiss();
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } on GamePackException catch (e) {
      if (mounted) AppToast.error(context, toastForGamePackError(e));
    } catch (_) {
      if (mounted) AppToast.error(context, 'Could not read this Lemon pack');
    }
  }

  Future<void> _importFull() async {
    if (_busy) return;
    final path = await pickLemonPackPath();
    if (path == null || !mounted) return;

    try {
      final inspected = await widget.packs.inspect(path);
      if (!mounted) return;
      if (inspected is! SinglePackInspect) {
        AppToast.error(context, 'Expected a full pack');
        return;
      }
      final info = inspected.info;
      if (info.kind != GamePackKind.full) {
        AppToast.error(context, 'Expected a full pack');
        return;
      }

      if (mounted) Navigator.pop(context);

      await runFullPackImport(
        context: context,
        packs: widget.packs,
        library: widget.library,
        zipPath: path,
        info: info,
        longPressContext: widget.game,
        onImportedFull: widget.onImportedFull,
        onBusyStart: widget.onFullImportBusyStart,
        onBusyEnd: widget.onFullImportBusyEnd,
        silentSuccess: widget.onImportedFull != null,
      );
    } on GamePackException catch (e) {
      if (mounted) AppToast.error(context, toastForGamePackError(e));
    } catch (_) {
      if (mounted) AppToast.error(context, 'Could not read this Lemon pack');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShellSheetActionColumn(
      header: ShellSheetTitleBar(title: 'Backup · ${widget.game.title}'),
      children: [
        ShellSheetAction(
          icon: HugeIcons.strokeRoundedFloppyDisk,
          label: 'Export save pack',
          onTap: _busy ? () {} : _exportSave,
        ),
        ShellSheetAction(
          icon: HugeIcons.strokeRoundedDownload01,
          label: 'Import save pack',
          onTap: _busy ? () {} : _importSave,
        ),
        ShellSheetAction(
          icon: HugeIcons.strokeRoundedFloppyDisk,
          label: 'Export full pack',
          onTap: _busy ? () {} : _exportFull,
        ),
        ShellSheetAction(
          icon: HugeIcons.strokeRoundedDownload01,
          label: 'Import full pack',
          onTap: _busy ? () {} : _importFull,
        ),
        const SizedBox(height: HomeSpacing.sm),
      ],
    );
  }
}
