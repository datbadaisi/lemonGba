import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/storage/game_pack_port.dart';
import 'pack_zip_io.dart';
import 'save_paths.dart';

/// Atomic play-data apply + boot recovery for pack import.
///
/// Second privileged writer of play-data paths (with [FileSaveStateRepository]
/// for session I/O). See docs/architecture.md dual-writer note.
final class PlayDataPackSwap {
  PlayDataPackSwap(this.paths);

  final SavePaths paths;

  /// Boot / construct recovery for mid-swap crashes.
  Future<void> recoverInterruptedSwaps() async {
    await paths.ensureDirs();

    final statesRoot = paths.statesDir;
    if (await statesRoot.exists()) {
      await for (final entity in statesRoot.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = p.basename(entity.path);
        if (name.endsWith('.importing')) {
          await PackZipIo.deleteDirQuietly(entity);
          continue;
        }
        if (!name.endsWith('.bak')) continue;
        final id = name.substring(0, name.length - 4);
        if (id.isEmpty) continue;
        final live = Directory(paths.stateDirForGame(id));
        if (!await live.exists()) {
          try {
            await entity.rename(live.path);
          } catch (_) {}
        } else {
          await PackZipIo.deleteDirQuietly(entity);
        }
      }
    }

    final savesRoot = paths.savesDir;
    if (await savesRoot.exists()) {
      await for (final entity in savesRoot.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.endsWith('.sav.importing') ||
            name.endsWith('.sav.importing.tombstone')) {
          await PackZipIo.deleteFileQuietly(entity);
          continue;
        }
        if (!name.endsWith('.sav.bak')) continue;
        final id = name.substring(0, name.length - 8);
        if (id.isEmpty) continue;
        final live = File(paths.savPathForGame(id));
        if (!await live.exists()) {
          try {
            await entity.rename(live.path);
          } catch (_) {}
        } else {
          await PackZipIo.deleteFileQuietly(entity);
        }
      }
    }
  }

  /// Apply play data from a staged single-game tree (`saves/`, `states/`).
  Future<void> applyFromStage({
    required String gameId,
    required Directory stageDir,
  }) async {
    await paths.ensureDirs();

    final liveStates = Directory(paths.stateDirForGame(gameId));
    final importingStates = Directory('${liveStates.path}.importing');
    final bakStates = Directory('${liveStates.path}.bak');

    final liveSav = File(paths.savPathForGame(gameId));
    final importingSav = File('${liveSav.path}.importing');
    final tombstone = File('${liveSav.path}.importing.tombstone');
    final bakSav = File('${liveSav.path}.bak');

    await PackZipIo.deleteDirQuietly(importingStates);
    await PackZipIo.deleteFileQuietly(importingSav);
    await PackZipIo.deleteFileQuietly(tombstone);

    try {
      await importingStates.create(recursive: true);

      final stageStates = Directory(p.join(stageDir.path, 'states'));
      if (await stageStates.exists()) {
        await for (final entity in stageStates.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          if (!_isAllowedStateFileName(name)) continue;
          final dest = File(p.join(importingStates.path, name));
          await entity.copy(dest.path);
        }
      }

      final stageSav = File(p.join(stageDir.path, 'saves', 'cartridge.sav'));
      if (await stageSav.exists()) {
        await stageSav.copy(importingSav.path);
      } else {
        await tombstone.writeAsString('', flush: true);
      }

      final hasImporting = await importingSav.exists();
      final hasTomb = await tombstone.exists();
      if (hasImporting == hasTomb) {
        throw const GamePackException(
          GamePackErrorCode.ioFailure,
          'Invalid cartridge staging',
        );
      }

      if (await bakStates.exists()) {
        await PackZipIo.deleteDirQuietly(bakStates);
      }
      var statesMovedToBak = false;
      if (await liveStates.exists()) {
        await liveStates.rename(bakStates.path);
        statesMovedToBak = true;
      }
      try {
        await importingStates.rename(liveStates.path);
      } catch (e) {
        if (statesMovedToBak && await bakStates.exists()) {
          try {
            await bakStates.rename(liveStates.path);
          } catch (_) {}
        }
        throw GamePackException(
          GamePackErrorCode.ioFailure,
          'Failed to apply savestates: $e',
        );
      }

      var savMovedToBak = false;
      if (await bakSav.exists()) {
        await PackZipIo.deleteFileQuietly(bakSav);
      }
      try {
        if (await liveSav.exists()) {
          await liveSav.rename(bakSav.path);
          savMovedToBak = true;
        }
        if (await importingSav.exists()) {
          await importingSav.rename(liveSav.path);
        } else if (await tombstone.exists()) {
          if (await liveSav.exists()) {
            await liveSav.delete();
          }
          await tombstone.delete();
        }
      } catch (e) {
        if (savMovedToBak &&
            !await liveSav.exists() &&
            await bakSav.exists()) {
          try {
            await bakSav.rename(liveSav.path);
          } catch (_) {}
        }
        throw GamePackException(
          GamePackErrorCode.ioFailure,
          'Failed to apply cartridge save: $e',
        );
      }

      await PackZipIo.deleteDirQuietly(bakStates);
      await PackZipIo.deleteFileQuietly(bakSav);
      await PackZipIo.deleteFileQuietly(importingSav);
      await PackZipIo.deleteFileQuietly(tombstone);
    } catch (e) {
      await PackZipIo.deleteDirQuietly(importingStates);
      await PackZipIo.deleteFileQuietly(importingSav);
      await PackZipIo.deleteFileQuietly(tombstone);
      if (e is GamePackException) rethrow;
      throw GamePackException(GamePackErrorCode.ioFailure, e.toString());
    }
  }

  bool _isAllowedStateFileName(String name) {
    if (name == 'quick_rotate.json') return true;
    final quick = RegExp(r'^quick(\d+)\.state$').firstMatch(name);
    if (quick != null) {
      final n = int.tryParse(quick.group(1)!);
      return n != null && n >= 1 && n <= SavePaths.quickSaveSlotCount;
    }
    final slot = RegExp(r'^slot(\d+)\.state$').firstMatch(name);
    if (slot != null) {
      final n = int.tryParse(slot.group(1)!);
      return n != null && n >= 1 && n <= SavePaths.manualSlotCount;
    }
    return false;
  }
}
