import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gba_emulator/application/play/play_session_controller.dart';
import 'package:gba_emulator/core/emulation/emulator_input.dart';
import 'package:gba_emulator/core/emulation/emulator_session.dart';
import 'package:gba_emulator/core/storage/save_state_repository.dart';

void main() {
  test(
    'quick save writes the next slot and advances only after success',
    () async {
      final saves = _MemorySaves();
      final emulator = _FakeSession();
      final controller = PlaySessionController(
        emulator: emulator,
        saveStates: saves,
        romPath: '/roms/demo.gba',
        gameId: 'demo',
        cartridgeSavePath: '/saves/demo.sav',
      );

      expect(await controller.saveNextQuick(), isTrue);
      expect(saves.quick['demo:1'], [1, 2, 3]);
      expect(saves.recorded, [1]);
    },
  );

  test('load uses repository bytes rather than a path in the shell', () async {
    final saves = _MemorySaves()..quick['demo:2'] = [4, 5];
    final emulator = _FakeSession();
    final controller = PlaySessionController(
      emulator: emulator,
      saveStates: saves,
      romPath: '/roms/demo.gba',
      gameId: 'demo',
      cartridgeSavePath: '/saves/demo.sav',
    );

    expect(await controller.loadQuick(2), isTrue);
    expect(emulator.applied, [4, 5]);
  });

  test('startNewGame wipes cartridge save and resets, keeps savestates', () async {
    final saves = _MemorySaves()..quick['demo:1'] = [9];
    final emulator = _FakeSession();
    final controller = PlaySessionController(
      emulator: emulator,
      saveStates: saves,
      romPath: '/roms/demo.gba',
      gameId: 'demo',
      cartridgeSavePath: '/saves/demo.sav',
    );

    expect(await controller.startNewGame(), isTrue);
    expect(emulator.wipeCalls, 1);
    expect(emulator.resetCalls, 1);
    expect(saves.quick['demo:1'], [9]);
  });

  test('loadMostRecentQuick uses repository ring slot', () async {
    final saves = _MemorySaves()
      ..quick['demo:2'] = [7, 8]
      ..recorded.add(2);
    final emulator = _FakeSession();
    final controller = PlaySessionController(
      emulator: emulator,
      saveStates: saves,
      romPath: '/roms/demo.gba',
      gameId: 'demo',
      cartridgeSavePath: '/saves/demo.sav',
    );

    expect(await controller.loadMostRecentQuick(), isTrue);
    expect(emulator.applied, [7, 8]);
  });

  test('loadMostRecentQuick is false when no slots exist', () async {
    final controller = PlaySessionController(
      emulator: _FakeSession(),
      saveStates: _MemorySaves(),
      romPath: '/roms/demo.gba',
      gameId: 'demo',
      cartridgeSavePath: '/saves/demo.sav',
    );

    expect(await controller.loadMostRecentQuick(), isFalse);
  });
}

class _FakeSession implements EmulatorSession {
  List<int>? applied;
  int wipeCalls = 0;
  int resetCalls = 0;

  @override
  String get coreVersion => 'fake';
  @override
  int get height => 160;
  @override
  bool get isLoaded => true;
  @override
  bool get isRunning => false;
  @override
  String? get romPath => null;
  @override
  int get width => 240;
  @override
  Future<bool> applyState(Uint8List bytes) async {
    applied = bytes;
    return true;
  }

  @override
  Future<Uint8List?> captureState() async => Uint8List.fromList([1, 2, 3]);
  @override
  Future<void> dispose() async {}
  @override
  Future<void> flushSave() async {}
  @override
  String gameTitle() => 'Fake';
  @override
  Future<void> loadRom(String path, {String? savPath}) async {}
  @override
  Future<void> reset() async {
    resetCalls++;
  }

  @override
  Future<bool> wipeCartridgeSave() async {
    wipeCalls++;
    return true;
  }

  @override
  void setInput(EmulatorInput input, bool pressed) {}
  @override
  void setInputMask(int mask) {}
  @override
  void setVolume(double volume) {}
  @override
  double get speed => 1.0;
  @override
  void setSpeed(double speed) {}
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
}

class _MemorySaves implements SaveStateRepository {
  final Map<String, List<int>> quick = {};
  final List<int> recorded = [];

  @override
  int get manualSlotCount => 5;
  @override
  int get quickSlotCount => 10;
  String _key(String game, int slot) => '$game:$slot';
  @override
  Future<List<int>?> loadManual(String gameId, int slot) async => null;
  @override
  Future<List<int>?> loadQuick(String gameId, int slot) async =>
      quick[_key(gameId, slot)];
  @override
  Future<List<DateTime?>> manualSlotTimes(String gameId) async =>
      List.filled(5, null);
  @override
  Future<int?> mostRecentQuickSlot(String gameId) async =>
      recorded.isEmpty ? null : recorded.last;
  @override
  Future<int> nextQuickSlot(String gameId) async => 1;
  @override
  Future<void> prepareGame(String gameId) async {}
  @override
  Future<List<DateTime?>> quickSlotTimes(String gameId) async =>
      List.filled(10, null);
  @override
  Future<void> recordQuickSlot(String gameId, int slot) async =>
      recorded.add(slot);
  @override
  Future<bool> saveManual(String gameId, int slot, List<int> bytes) async =>
      true;
  @override
  Future<bool> saveQuick(String gameId, int slot, List<int> bytes) async {
    quick[_key(gameId, slot)] = List.of(bytes);
    return true;
  }
}
