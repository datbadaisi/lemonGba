import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/entitlements/free_limits.dart';
import '../../core/storage/game_pack_port.dart';
import '../../infrastructure/library/game_library.dart';
import '../../models/library_game.dart';
import '../common/app_toast.dart';
import '../common/shell_confirm_dialog.dart';

/// Unified **Add game** picker: GBA ROM (`.gba` / `.bin`) or Lemon **full** pack.
///
/// Returns the library entry when a ROM was added (or re-imported). Full-pack
/// imports report via [onImportedFull] and return that game when successful.
/// Cancel / save-pack / errors return `null` (toasts already shown).
Future<LibraryGame?> addGameFromPicker({
  required BuildContext context,
  required GamePackPort packs,
  required GameLibrary library,
  ValueChanged<LibraryGame>? onImportedFull,
  void Function(String message)? onWorkStart,
  VoidCallback? onWorkEnd,
}) async {
  final result = await _pickRomOrPackFile();
  if (result == null || !context.mounted) return null;

  final file = result;
  final name = file.name.isEmpty ? 'game.gba' : file.name;
  final path = file.path;
  if (path == null) {
    if (context.mounted) {
      AppToast.error(context, 'Picker did not provide a readable file');
    }
    return null;
  }

  if (GameLibrary.isAllowedRomName(name)) {
    onWorkStart?.call('Adding game…');
    try {
      return await library.addFromPath(path, originalName: name);
    } finally {
      onWorkEnd?.call();
    }
  }

  LibraryGame? imported;
  await importPackFromPath(
    context: context,
    packs: packs,
    library: library,
    zipPath: path,
    onImportedFull: (g) {
      imported = g;
      onImportedFull?.call(g);
    },
    onFullImportBusyStart: () => onWorkStart?.call('Importing pack…'),
    onFullImportBusyEnd: onWorkEnd,
  );
  return imported;
}

/// Home-level: pick any Lemon pack and route by kind.
Future<void> importPackFromPicker({
  required BuildContext context,
  required GamePackPort packs,
  required GameLibrary library,
  LibraryGame? longPressContext,
  ValueChanged<LibraryGame>? onImportedFull,
  VoidCallback? onFullImportBusyStart,
  VoidCallback? onFullImportBusyEnd,
}) async {
  final path = await pickLemonPackPath();
  if (path == null || !context.mounted) return;

  await importPackFromPath(
    context: context,
    packs: packs,
    library: library,
    zipPath: path,
    longPressContext: longPressContext,
    onImportedFull: onImportedFull,
    onFullImportBusyStart: onFullImportBusyStart,
    onFullImportBusyEnd: onFullImportBusyEnd,
  );
}

/// Inspect [zipPath] and import a **full** Lemon pack (single).
///
/// Save packs → toast to use Backup & restore. Multi packs → toast to use
/// Multi backup. Invalid files → error toast.
Future<void> importPackFromPath({
  required BuildContext context,
  required GamePackPort packs,
  required GameLibrary library,
  required String zipPath,
  LibraryGame? longPressContext,
  ValueChanged<LibraryGame>? onImportedFull,
  VoidCallback? onFullImportBusyStart,
  VoidCallback? onFullImportBusyEnd,
}) async {
  try {
    final inspected = await packs.inspect(zipPath);
    if (!context.mounted) return;

    switch (inspected) {
      case MultiPackInspect():
        AppToast.error(
          context,
          library.pro.isPro
              ? 'Use Multi backup to import multi packs'
              : FreeTierMessages.multiBackup,
        );
        return;
      case SinglePackInspect(:final info):
        if (info.kind == GamePackKind.saves) {
          AppToast.error(
            context,
            'Open a game’s Backup & restore to import a save pack',
          );
          return;
        }
        await runFullPackImport(
          context: context,
          packs: packs,
          library: library,
          zipPath: zipPath,
          info: info,
          longPressContext: longPressContext,
          onImportedFull: onImportedFull,
          onBusyStart: onFullImportBusyStart,
          onBusyEnd: onFullImportBusyEnd,
          silentSuccess: onImportedFull != null,
        );
    }
  } on GamePackException catch (e) {
    if (context.mounted) AppToast.error(context, toastForGamePackError(e));
  } catch (_) {
    if (context.mounted) {
      AppToast.error(context, 'Could not read this Lemon pack');
    }
  }
}

/// Returns true if import completed successfully.
Future<bool> runFullPackImport({
  required BuildContext context,
  required GamePackPort packs,
  required GameLibrary library,
  required String zipPath,
  required GamePackInfo info,
  LibraryGame? longPressContext,
  ValueChanged<LibraryGame>? onImportedFull,
  VoidCallback? onBusyStart,
  VoidCallback? onBusyEnd,
  bool silentSuccess = false,
}) async {
  final packTitle = info.title?.trim().isNotEmpty == true
      ? info.title!.trim()
      : (library.byId(info.gameId)?.title ?? 'Game');

  final existing = library.byId(info.gameId);
  final GamePackImportMode mode;
  if (existing != null) {
    final different =
        longPressContext != null && longPressContext.id != info.gameId;
    final extra = different
        ? '\n\nThis pack is for a different game than the one you selected.'
        : '';
    final ok = await showShellConfirmDialog(
      context,
      title: 'Replace game data?',
      message:
          '“$packTitle” is already in your library. ROM, name/art '
          '(if included), and all progress will be overwritten. If the pack '
          'includes groups, they are merged with your local groups.'
          '$extra',
      confirmLabel: 'Replace',
      destructive: true,
    );
    if (ok != true || !context.mounted) return false;
    mode = GamePackImportMode.replaceExisting;
  } else {
    mode = GamePackImportMode.createNew;
  }

  onBusyStart?.call();
  try {
    final result = await packs.importFullPack(zipPath: zipPath, mode: mode);
    if (!context.mounted) return false;

    final g = library.byId(result.gameId);
    if (g != null) onImportedFull?.call(g);

    if (!silentSuccess) {
      if (result.createdNew) {
        AppToast.success(
          context,
          '“${result.title ?? packTitle}” added from pack',
        );
      } else {
        AppToast.success(
          context,
          '“${result.title ?? packTitle}” updated from pack',
        );
      }
    }

    if (result.skippedAvatar || result.skippedCover) {
      final parts = <String>[];
      if (result.skippedAvatar) parts.add('tile art');
      if (result.skippedCover) parts.add('cover');
      AppToast.error(
        context,
        'Imported without ${parts.join(' & ')} (free plan limit)',
      );
    }
    if (result.groups.skippedCreate > 0) {
      AppToast.error(
        context,
        'Some groups were not restored (free plan limit)',
      );
    }
    return true;
  } on GamePackException catch (e) {
    if (context.mounted) AppToast.error(context, toastForGamePackError(e));
    return false;
  } catch (_) {
    if (context.mounted) AppToast.error(context, 'Could not import pack');
    return false;
  } finally {
    onBusyEnd?.call();
  }
}

/// File picker for a Lemon pack (single or multi).
Future<String?> pickLemonPackPath({
  String dialogTitle = 'Select Lemon pack',
}) async {
  final file = await FilePicker.pickFile(
    type: FileType.any,
    dialogTitle: dialogTitle,
  );
  return file?.path;
}

Future<PlatformFile?> _pickRomOrPackFile() {
  final useOsExtensionFilter =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  return FilePicker.pickFile(
    type: useOsExtensionFilter ? FileType.custom : FileType.any,
    allowedExtensions: useOsExtensionFilter
        ? const ['gba', 'bin', 'zip']
        : null,
    dialogTitle: 'Select GBA ROM or Lemon pack',
  );
}

/// Shared export orchestration: busy flag, progress toast, deliver, cleanup.
Future<void> runGamePackExport({
  required BuildContext context,
  required bool busy,
  required void Function(bool) setBusy,
  required String workingMessage,
  required String successMessage,
  required Future<GamePackExportResult> Function() export,
  String failureMessage = 'Could not export pack',
}) async {
  if (busy) return;
  setBusy(true);
  AppProgressToast.show(context, message: workingMessage);
  try {
    final result = await export();
    if (!context.mounted) {
      AppProgressToast.dismiss();
      return;
    }
    AppProgressToast.update('Saving pack…', progress: 0.85);
    final ok = await deliverGamePackExport(context, result);
    if (!context.mounted) {
      AppProgressToast.dismiss();
      return;
    }
    if (ok) {
      AppProgressToast.completeSuccess(context, successMessage);
    } else {
      AppProgressToast.dismiss();
    }
  } on FreeTierLimitException catch (e) {
    if (context.mounted) {
      AppProgressToast.completeError(context, e.message);
    } else {
      AppProgressToast.dismiss();
    }
  } on GamePackException catch (e) {
    if (context.mounted) {
      AppProgressToast.completeError(context, toastForGamePackError(e));
    } else {
      AppProgressToast.dismiss();
    }
  } catch (_) {
    if (context.mounted) {
      AppProgressToast.completeError(context, failureMessage);
    } else {
      AppProgressToast.dismiss();
    }
  } finally {
    if (context.mounted) setBusy(false);
  }
}

/// Platform export: Android prefers share for large/full packs; desktop saveFile.
Future<bool> deliverGamePackExport(
  BuildContext context,
  GamePackExportResult result,
) async {
  final temp = File(result.tempFilePath);
  try {
    final useShare =
        !kIsWeb &&
        (Platform.isAndroid ||
            result.kind == GamePackKind.full ||
            result.byteLength > kGamePackShareBytesThreshold);

    if (useShare && (Platform.isAndroid || Platform.isIOS)) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(result.tempFilePath, name: result.suggestedFileName)],
          subject: result.suggestedFileName,
        ),
      );
      return true;
    }

    if (result.byteLength <= kGamePackShareBytesThreshold) {
      final bytes = await temp.readAsBytes();
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save Lemon pack',
        fileName: result.suggestedFileName,
        bytes: bytes,
      );
      return saved != null || Platform.isAndroid;
    }

    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Save Lemon pack',
      fileName: result.suggestedFileName,
      bytes: Uint8List(0),
    );
    if (savedUri == null || savedUri.scheme != 'file') return false;
    await temp.copy(savedUri.toFilePath());
    return true;
  } catch (_) {
    if (context.mounted) AppToast.error(context, 'Could not export pack');
    return false;
  } finally {
    try {
      if (await temp.exists()) await temp.delete();
    } catch (_) {}
  }
}

/// User-facing message for a [GamePackException].
String toastForGamePackError(GamePackException e) {
  return switch (e.code) {
    GamePackErrorCode.wrongGame => 'This pack belongs to a different game',
    GamePackErrorCode.wrongKind => e.message ?? 'Wrong pack type',
    GamePackErrorCode.romMissing =>
      'ROM file missing — cannot export full pack',
    GamePackErrorCode.gameNotInLibrary => 'Game not in library',
    GamePackErrorCode.invalidFormat ||
    GamePackErrorCode.unsupportedVersion ||
    GamePackErrorCode.corruptEntry =>
      e.message ?? 'Could not read this Lemon pack',
    GamePackErrorCode.modeMismatch => e.message ?? 'Import mode mismatch',
    GamePackErrorCode.ioFailure => e.message ?? 'Could not import pack',
    GamePackErrorCode.exportTooLarge => 'Pack is too large to export this way',
  };
}
