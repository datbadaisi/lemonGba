import 'dart:io';

import '../../core/storage/save_state_repository.dart';
import 'save_paths.dart';

/// Filesystem implementation kept behind [SaveStateRepository].
class FileSaveStateRepository implements SaveStateRepository {
  FileSaveStateRepository(this._paths);
  final SavePaths _paths;

  @override
  int get quickSlotCount => SavePaths.quickSaveSlotCount;
  @override
  int get manualSlotCount => SavePaths.manualSlotCount;

  @override
  Future<void> prepareGame(String gameId) async {
    await _paths.ensureStateDir(gameId);
    await _paths.migrateLegacyQuickSaveIfNeeded(gameId);
  }

  @override
  Future<int?> mostRecentQuickSlot(String gameId) async {
    final ring = await _paths.lastQuickSaveSlot(gameId);
    if (ring != null) return ring;

    // Ring metadata missing (legacy / wiped pointer): newest mtime wins.
    final times = await quickSlotTimes(gameId);
    DateTime? newest;
    int? slot;
    for (var i = 0; i < times.length; i++) {
      final m = times[i];
      if (m == null) continue;
      if (newest == null || m.isAfter(newest)) {
        newest = m;
        slot = i + 1;
      }
    }
    return slot;
  }
  @override
  Future<int> nextQuickSlot(String gameId) => _paths.nextQuickSaveSlot(gameId);
  @override
  Future<void> recordQuickSlot(String gameId, int slot) =>
      _paths.advanceQuickSaveRotation(gameId, slot);
  @override
  Future<List<DateTime?>> quickSlotTimes(String gameId) =>
      _slotTimes(gameId, quick: true);
  @override
  Future<List<DateTime?>> manualSlotTimes(String gameId) =>
      _slotTimes(gameId, quick: false);

  Future<List<DateTime?>> _slotTimes(
    String gameId, {
    required bool quick,
  }) async {
    await prepareGame(gameId);
    final count = quick ? quickSlotCount : manualSlotCount;
    return [
      for (var i = 1; i <= count; i++)
        await _modified(
          quick
              ? _paths.quickStatePathForGame(gameId, i)
              : _paths.statePathForGame(gameId, i),
        ),
    ];
  }

  Future<DateTime?> _modified(String path) async {
    final f = File(path);
    return await f.exists() ? (await f.stat()).modified : null;
  }

  @override
  Future<bool> saveQuick(String gameId, int slot, List<int> bytes) =>
      _write(_paths.quickStatePathForGame(gameId, slot), bytes);
  @override
  Future<List<int>?> loadQuick(String gameId, int slot) =>
      _read(_paths.quickStatePathForGame(gameId, slot));
  @override
  Future<bool> saveManual(String gameId, int slot, List<int> bytes) =>
      _write(_paths.statePathForGame(gameId, slot), bytes);
  @override
  Future<List<int>?> loadManual(String gameId, int slot) =>
      _read(_paths.statePathForGame(gameId, slot));

  Future<List<int>?> _read(String path) async {
    final f = File(path);
    return await f.exists() ? f.readAsBytes() : null;
  }

  Future<bool> _write(String path, List<int> bytes) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    final backup = File('${file.path}.bak');
    if (await backup.exists()) {
      await backup.delete();
    }
    if (await file.exists()) {
      await file.rename(backup.path);
    }
    try {
      await temp.rename(file.path);
      if (await backup.exists()) {
        await backup.delete();
      }
      return true;
    } catch (_) {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }
}
