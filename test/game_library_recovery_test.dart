import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gba_emulator/infrastructure/entitlements/pro_access.dart';
import 'package:gba_emulator/infrastructure/library/game_library.dart';
import 'package:gba_emulator/infrastructure/storage/save_paths.dart';
import 'package:gba_emulator/models/library_game.dart';

void main() {
  late Directory temp;
  late SavePaths paths;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lemongba_library_');
    paths = SavePaths.forRoot(temp);
    await paths.ensureDirs();
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'load recovers staged index after interruption between renames',
    () async {
      final game = LibraryGame(
        id: 'abc',
        displayName: 'Custom title',
        romFileName: 'abc_game.gba',
        addedAt: DateTime.utc(2024),
        playTimeSeconds: 123,
      );
      await File(paths.romPathForFileName(game.romFileName)).writeAsBytes([1]);
      final index = paths.libraryIndexFile;
      await File('${index.path}.tmp').writeAsString(
        jsonEncode({
          'games': [game.toJson()],
          'groups': [],
        }),
      );
      await File('${index.path}.bak').writeAsString(
        jsonEncode({
          'games': [game.copyWith(displayName: 'Old title').toJson()],
          'groups': [],
        }),
      );

      final library = GameLibrary(paths, pro: await ProAccess.open(paths));
      await library.load();

      expect(library.byId('abc')?.displayName, 'Custom title');
      expect(library.byId('abc')?.playTimeSeconds, 123);
      expect(await index.exists(), isTrue);
    },
  );
}
