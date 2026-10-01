import 'dart:typed_data';

import '../../core/emulation/emulator_session.dart';
import '../../core/storage/save_state_repository.dart';

/// Coordinates emulation and persistence for one game.
///
/// This is deliberately Flutter-free: screens render state and send intents;
/// they never compute state-file paths or own the quick-save ring.
class PlaySessionController {
  PlaySessionController({
    required this.emulator,
    required this.saveStates,
    required this.romPath,
    required this.gameId,
    required this.cartridgeSavePath,
  });

  final EmulatorSession emulator;
  final SaveStateRepository saveStates;
  final String romPath;
  final String gameId;
  final String cartridgeSavePath;

  Future<void> load() async {
    await saveStates.prepareGame(gameId);
    await emulator.loadRom(romPath, savPath: cartridgeSavePath);
  }

  Future<void> start() => emulator.start();
  Future<void> stop() => emulator.stop();
  Future<void> reset() => emulator.reset();

  /// True New Game: blank cartridge battery save and soft-reset to title.
  ///
  /// Does not delete quick/manual savestates — those stay as independent
  /// snapshots the player can still load.
  ///
  /// Returns whether the cartridge wipe succeeded. Soft-reset still runs so
  /// the player leaves the current session even if wipe fails.
  Future<bool> startNewGame() async {
    await emulator.stop();
    final wiped = await emulator.wipeCartridgeSave();
    await emulator.reset();
    return wiped;
  }

  /// Saves an explicitly chosen quick slot without altering ring metadata.
  Future<bool> saveQuick(int slot) async {
    final bytes = await emulator.captureState();
    if (bytes == null) return false;
    return saveStates.saveQuick(gameId, slot, bytes);
  }

  /// Saves to the next ring slot, then advances the ring after a successful
  /// write. This is used for Save & Exit and long-press quick-save.
  Future<bool> saveNextQuick() async {
    final slot = await saveStates.nextQuickSlot(gameId);
    final saved = await saveQuick(slot);
    if (saved) await saveStates.recordQuickSlot(gameId, slot);
    return saved;
  }

  Future<bool> loadQuick(int slot) => _load(saveStates.loadQuick(gameId, slot));

  /// Loads the most recent quick save (ring metadata, else newest mtime).
  ///
  /// Returns false when no quick slot exists or apply fails.
  Future<bool> loadMostRecentQuick() async {
    final slot = await mostRecentQuickSlot();
    if (slot == null) return false;
    return loadQuick(slot);
  }

  Future<bool> saveManual(int slot) async {
    final bytes = await emulator.captureState();
    if (bytes == null) return false;
    return saveStates.saveManual(gameId, slot, bytes);
  }

  Future<bool> loadManual(int slot) =>
      _load(saveStates.loadManual(gameId, slot));

  Future<bool> _load(Future<List<int>?> source) async {
    final bytes = await source;
    if (bytes == null) return false;
    return emulator.applyState(Uint8List.fromList(bytes));
  }

  Future<int?> mostRecentQuickSlot() => saveStates.mostRecentQuickSlot(gameId);
  Future<List<DateTime?>> quickSlotTimes() => saveStates.quickSlotTimes(gameId);
  Future<List<DateTime?>> manualSlotTimes() =>
      saveStates.manualSlotTimes(gameId);
}
