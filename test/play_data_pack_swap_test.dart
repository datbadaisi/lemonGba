import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gba_emulator/core/storage/game_pack_port.dart';
import 'package:gba_emulator/infrastructure/storage/play_data_pack_swap.dart';
import 'package:gba_emulator/infrastructure/storage/save_paths.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late SavePaths paths;
  const gameId = 'abc123';

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lemongba_swap_');
    paths = SavePaths.forRoot(temp);
    await paths.ensureDirs();
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'recovery rolls back states and save as one interrupted import',
    () async {
      final states = Directory(paths.stateDirForGame(gameId));
      final backup = Directory('${states.path}.bak');
      await backup.create();
      await File(p.join(backup.path, 'quick1.state')).writeAsBytes([1]);
      await states.create();
      await File(p.join(states.path, 'quick1.state')).writeAsBytes([2]);
      final sav = File(paths.savPathForGame(gameId));
      await sav.writeAsBytes([3]);
      final marker = File(
        p.join(paths.statesDir.path, '$gameId.pack_swap.json'),
      );
      await marker.writeAsString(
        jsonEncode({'hadStates': true, 'hadSav': true}),
      );

      await PlayDataPackSwap(paths).recoverInterruptedSwaps();

      expect(await File(p.join(states.path, 'quick1.state')).readAsBytes(), [
        1,
      ]);
      expect(await sav.readAsBytes(), [3]);
      expect(await backup.exists(), isFalse);
      expect(await marker.exists(), isFalse);
    },
  );

  test('recovery removes new data when game had no old play data', () async {
    final states = Directory(paths.stateDirForGame(gameId));
    await states.create();
    await File(p.join(states.path, 'quick1.state')).writeAsBytes([2]);
    final sav = File(paths.savPathForGame(gameId));
    await sav.writeAsBytes([3]);
    final marker = File(p.join(paths.statesDir.path, '$gameId.pack_swap.json'));
    await marker.writeAsString(
      jsonEncode({'hadStates': false, 'hadSav': false}),
    );

    await PlayDataPackSwap(paths).recoverInterruptedSwaps();

    expect(await states.exists(), isFalse);
    expect(await sav.exists(), isFalse);
    expect(await marker.exists(), isFalse);
  });

  test('failed cartridge swap rolls back already replaced states', () async {
    final states = Directory(paths.stateDirForGame(gameId));
    await states.create();
    final oldState = File(p.join(states.path, 'quick1.state'));
    await oldState.writeAsBytes([1]);
    final sav = File(paths.savPathForGame(gameId));
    await sav.writeAsBytes([3]);

    final stage = Directory(p.join(temp.path, 'stage'));
    await Directory(p.join(stage.path, 'states')).create(recursive: true);
    await File(p.join(stage.path, 'states', 'quick1.state')).writeAsBytes([2]);
    await Directory(p.join(stage.path, 'saves')).create();
    await File(p.join(stage.path, 'saves', 'cartridge.sav')).writeAsBytes([4]);

    // A directory at the backup file path forces the second resource swap
    // to fail after the savestate directory was already replaced.
    await Directory('${sav.path}.bak').create();
    await expectLater(
      PlayDataPackSwap(paths).applyFromStage(gameId: gameId, stageDir: stage),
      throwsA(isA<GamePackException>()),
    );

    expect(await oldState.readAsBytes(), [1]);
    expect(await sav.readAsBytes(), [3]);
  });
}
