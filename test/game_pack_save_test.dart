import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gba_emulator/core/entitlements/free_limits.dart';
import 'package:gba_emulator/core/storage/game_pack_port.dart';
import 'package:gba_emulator/infrastructure/entitlements/pro_access.dart';
import 'package:gba_emulator/infrastructure/library/game_library.dart';
import 'package:gba_emulator/infrastructure/library/rom_identity.dart';
import 'package:gba_emulator/infrastructure/storage/pack_manifest.dart';
import 'package:gba_emulator/infrastructure/storage/save_paths.dart';
import 'package:gba_emulator/infrastructure/storage/zip_game_pack_service.dart';
import 'package:gba_emulator/models/library_game.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late SavePaths paths;
  late GameLibrary library;
  late ZipGamePackService packs;
  late String gameId;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lemongba_pack_');
    paths = SavePaths.forRoot(temp);
    await paths.ensureDirs();
  });

  tearDown(() async {
    try {
      if (await temp.exists()) await temp.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> seedGame() async {
    final romFile = File(p.join(temp.path, 'src.gba'));
    await romFile.writeAsBytes(List<int>.generate(64, (i) => i));
    gameId = (await RomIdentity.fromFile(romFile)).value;
    final short = gameId.substring(0, 8);
    final romName = '${short}_Test.gba';
    await romFile.copy(paths.romPathForFileName(romName));

    await paths.libraryIndexFile.writeAsString(
      jsonEncode({
        'games': [
          LibraryGame(
            id: gameId,
            displayName: 'Test Game',
            romFileName: romName,
            addedAt: DateTime.utc(2024, 1, 1),
          ).toJson(),
        ],
      }),
    );
    final pro = await ProAccess.open(paths);
    library = GameLibrary(paths, pro: pro);
    await library.load();
    packs = ZipGamePackService(paths: paths, library: library);

    await File(paths.savPathForGame(gameId)).writeAsBytes([1, 2, 3]);
    await paths.ensureStateDir(gameId);
    await File(paths.quickStatePathForGame(gameId, 1)).writeAsBytes([9]);
    await File(paths.statePathForGame(gameId, 2)).writeAsBytes([8]);
    await File(paths.quickRotateMetaPathForGame(gameId))
        .writeAsString('{"nextSlot": 2, "lastSlot": 1}');
  }

  Future<String> seedSecondGame() async {
    final romFile = File(p.join(temp.path, 'src2.gba'));
    await romFile.writeAsBytes(List<int>.generate(64, (i) => i + 40));
    final id = (await RomIdentity.fromFile(romFile)).value;
    final short = id.substring(0, 8);
    final romName = '${short}_Second.gba';
    await romFile.copy(paths.romPathForFileName(romName));

    final games = library.games.map((g) => g.toJson()).toList();
    games.add(
      LibraryGame(
        id: id,
        displayName: 'Second Game',
        romFileName: romName,
        addedAt: DateTime.utc(2024, 2, 1),
      ).toJson(),
    );
    await paths.libraryIndexFile.writeAsString(jsonEncode({'games': games}));
    await library.load();

    await File(paths.savPathForGame(id)).writeAsBytes([4, 5, 6]);
    await paths.ensureStateDir(id);
    await File(paths.quickStatePathForGame(id, 1)).writeAsBytes([11]);
    return id;
  }

  test('export/import save pack round-trips play data', () async {
    await seedGame();
    final exported = await packs.exportSavePack(
      gameId: gameId,
      titleForFileName: 'Test Game',
    );
    expect(
      exported.suggestedFileName,
      matches(RegExp(r'^Test Game \d{4}-\d{2}-\d{2}_\d{6}\.saves\.lemongba\.zip$')),
    );
    expect(File(exported.tempFilePath).existsSync(), isTrue);

    await paths.deletePlayDataForGame(gameId);
    expect(await File(paths.savPathForGame(gameId)).exists(), isFalse);

    final imported = await packs.importSavePack(
      zipPath: exported.tempFilePath,
      expectedGameId: gameId,
    );
    expect(imported.kind, GamePackKind.saves);
    expect(await File(paths.savPathForGame(gameId)).readAsBytes(), [1, 2, 3]);
    expect(
      await File(paths.quickStatePathForGame(gameId, 1)).readAsBytes(),
      [9],
    );
    expect(
      await File(paths.statePathForGame(gameId, 2)).readAsBytes(),
      [8],
    );
  });

  test('wrong game id is rejected', () async {
    await seedGame();
    final exported = await packs.exportSavePack(
      gameId: gameId,
      titleForFileName: 'Test Game',
    );
    await expectLater(
      packs.importSavePack(
        zipPath: exported.tempFilePath,
        expectedGameId: '0' * 64,
      ),
      throwsA(
        isA<GamePackException>().having(
          (e) => e.code,
          'code',
          GamePackErrorCode.wrongGame,
        ),
      ),
    );
  });

  test('empty save pack clears all play data including cartridge', () async {
    await seedGame();
    await paths.deletePlayDataForGame(gameId);
    final emptyExport = await packs.exportSavePack(
      gameId: gameId,
      titleForFileName: 'Test Game',
    );

    await File(paths.savPathForGame(gameId)).writeAsBytes([7, 7]);
    await paths.ensureStateDir(gameId);
    await File(paths.quickStatePathForGame(gameId, 3)).writeAsBytes([4]);

    await packs.importSavePack(
      zipPath: emptyExport.tempFilePath,
      expectedGameId: gameId,
    );
    expect(await File(paths.savPathForGame(gameId)).exists(), isFalse);
    expect(
      await File(paths.quickStatePathForGame(gameId, 3)).exists(),
      isFalse,
    );
  });

  test('inspect reads single pack kind and gameId', () async {
    await seedGame();
    final exported = await packs.exportSavePack(
      gameId: gameId,
      titleForFileName: 'Test Game',
    );
    final inspected = await packs.inspect(exported.tempFilePath);
    expect(inspected, isA<SinglePackInspect>());
    final info = (inspected as SinglePackInspect).info;
    expect(info.kind, GamePackKind.saves);
    expect(info.gameId, gameId);
    expect(info.title, 'Test Game');
  });

  test('full pack export/import creates library entry', () async {
    await seedGame();
    final exported = await packs.exportFullPack(
      gameId: gameId,
      titleForFileName: 'Test Game',
    );
    expect(
      exported.suggestedFileName,
      matches(RegExp(r'^Test Game \d{4}-\d{2}-\d{2}_\d{6}\.full\.lemongba\.zip$')),
    );

    await library.remove(gameId);
    expect(library.byId(gameId), isNull);

    final result = await packs.importFullPack(
      zipPath: exported.tempFilePath,
      mode: GamePackImportMode.createNew,
    );
    expect(result.createdNew, isTrue);
    expect(library.byId(gameId), isNotNull);
    expect(await File(paths.savPathForGame(gameId)).readAsBytes(), [1, 2, 3]);
  });

  test('multi save pack export/import round-trips several games', () async {
    await seedGame();
    final gameId2 = await seedSecondGame();
    await library.pro.setPro(true);

    final exported = await packs.exportMultiPack(
      kind: GamePackKind.saves,
      gameIds: [gameId, gameId2],
    );
    expect(
      exported.suggestedFileName,
      matches(
        RegExp(r'^Multi 2 games \d{4}-\d{2}-\d{2}_\d{6}\.saves\.multi\.lemongba\.zip$'),
      ),
    );

    final inspected = await packs.inspect(exported.tempFilePath);
    expect(inspected, isA<MultiPackInspect>());
    final info = (inspected as MultiPackInspect).info;
    expect(info.kind, GamePackKind.saves);
    expect(info.gameCount, 2);
    // Flat multi: root is games/<id>, not a nested zip path.
    expect(info.games.every((g) => g.root.startsWith('games/')), isTrue);

    await paths.deletePlayDataForGame(gameId);
    await paths.deletePlayDataForGame(gameId2);

    final result = await packs.importMultiPack(exported.tempFilePath);
    expect(result.imported, 2);
    expect(result.failed, 0);
    expect(await File(paths.savPathForGame(gameId)).readAsBytes(), [1, 2, 3]);
    expect(await File(paths.savPathForGame(gameId2)).readAsBytes(), [4, 5, 6]);
  });

  test('multi full pack export/import recreates library entries', () async {
    await seedGame();
    final gameId2 = await seedSecondGame();
    await library.pro.setPro(true);

    final exported = await packs.exportMultiPack(
      kind: GamePackKind.full,
      gameIds: [gameId, gameId2],
    );
    expect(
      exported.suggestedFileName,
      matches(
        RegExp(r'^Multi 2 games \d{4}-\d{2}-\d{2}_\d{6}\.full\.multi\.lemongba\.zip$'),
      ),
    );

    await library.remove(gameId);
    await library.remove(gameId2);
    expect(library.byId(gameId), isNull);
    expect(library.byId(gameId2), isNull);

    final result = await packs.importMultiPack(exported.tempFilePath);
    expect(result.imported, 2);
    expect(result.failed, 0);
    expect(library.byId(gameId), isNotNull);
    expect(library.byId(gameId2), isNotNull);
    expect(await File(paths.savPathForGame(gameId)).readAsBytes(), [1, 2, 3]);
    expect(await File(paths.savPathForGame(gameId2)).readAsBytes(), [4, 5, 6]);
  });

  test('multi save import skips games not in library', () async {
    await seedGame();
    final gameId2 = await seedSecondGame();
    await library.pro.setPro(true);

    final exported = await packs.exportMultiPack(
      kind: GamePackKind.saves,
      gameIds: [gameId, gameId2],
    );

    await library.remove(gameId2);

    final result = await packs.importMultiPack(exported.tempFilePath);
    expect(result.imported, 1);
    expect(result.skipped, 1);
    expect(result.failed, 0);
    expect(
      result.entries
          .where((e) => e.status == MultiGamePackEntryStatus.skipped)
          .single
          .gameId,
      gameId2,
    );
  });

  test('export multi with empty ids is rejected', () async {
    await seedGame();
    await library.pro.setPro(true);
    await expectLater(
      packs.exportMultiPack(kind: GamePackKind.saves, gameIds: []),
      throwsA(
        isA<GamePackException>().having(
          (e) => e.code,
          'code',
          GamePackErrorCode.invalidFormat,
        ),
      ),
    );
  });

  test('free tier blocks multi pack export', () async {
    await seedGame();
    expect(library.pro.isPro, isFalse);
    await expectLater(
      packs.exportMultiPack(kind: GamePackKind.saves, gameIds: [gameId]),
      throwsA(
        isA<FreeTierLimitException>().having(
          (e) => e.message,
          'message',
          FreeTierMessages.multiBackup,
        ),
      ),
    );
  });

  test('free tier blocks multi pack import', () async {
    await seedGame();
    await library.pro.setPro(true);
    final exported = await packs.exportMultiPack(
      kind: GamePackKind.saves,
      gameIds: [gameId],
    );
    await library.pro.setPro(false);
    await expectLater(
      packs.importMultiPack(exported.tempFilePath),
      throwsA(
        isA<FreeTierLimitException>().having(
          (e) => e.message,
          'message',
          FreeTierMessages.multiBackup,
        ),
      ),
    );
  });

  test('inspect multi wrong kind path still distinguishes formats', () async {
    await seedGame();
    await library.pro.setPro(true);
    final single = await packs.exportSavePack(
      gameId: gameId,
      titleForFileName: 'Test Game',
    );
    final inspected = await packs.inspect(single.tempFilePath);
    expect(inspected, isA<SinglePackInspect>());

    final multi = await packs.exportMultiPack(
      kind: GamePackKind.saves,
      gameIds: [gameId],
    );
    final multiInspected = await packs.inspect(multi.tempFilePath);
    expect(multiInspected, isA<MultiPackInspect>());
  });

  test('legacy nested multi pack (pack field) is rejected', () async {
    await seedGame();
    // Simulate unsupported legacy multi manifest shape.
    final map = {
      'format': PackManifest.multiFormat,
      'version': 1,
      'kind': 'saves',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'games': [
        {
          'gameId': gameId,
          'title': 'Test',
          'pack': 'packs/nested.saves.lemongba.zip',
        },
      ],
    };
    expect(
      () => PackManifest.parseMulti(map),
      throwsA(
        isA<GamePackException>().having(
          (e) => e.code,
          'code',
          GamePackErrorCode.unsupportedVersion,
        ),
      ),
    );
  });

  test('unsafe multi root path is rejected', () async {
    expect(
      () => PackManifest.parseMulti({
        'format': PackManifest.multiFormat,
        'version': 1,
        'kind': 'saves',
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'games': [
          {
            'gameId': 'abc',
            'title': 'x',
            'root': '../escape',
          },
        ],
      }),
      throwsA(
        isA<GamePackException>().having(
          (e) => e.code,
          'code',
          GamePackErrorCode.corruptEntry,
        ),
      ),
    );
  });

  test('multi full create+replace mix', () async {
    await seedGame();
    final gameId2 = await seedSecondGame();
    await library.pro.setPro(true);

    final exported = await packs.exportMultiPack(
      kind: GamePackKind.full,
      gameIds: [gameId, gameId2],
    );

    // Keep game1, remove game2 → import should replace + create.
    await library.remove(gameId2);
    await File(paths.savPathForGame(gameId)).writeAsBytes([99]);

    final result = await packs.importMultiPack(exported.tempFilePath);
    expect(result.imported, 2);
    expect(result.failed, 0);
    final e1 = result.entries.firstWhere((e) => e.gameId == gameId);
    final e2 = result.entries.firstWhere((e) => e.gameId == gameId2);
    expect(e1.createdNew, isFalse);
    expect(e2.createdNew, isTrue);
    expect(await File(paths.savPathForGame(gameId)).readAsBytes(), [1, 2, 3]);
    expect(library.byId(gameId2), isNotNull);
  });

  test('multi full pack restores groups and membership', () async {
    await seedGame();
    final gameId2 = await seedSecondGame();
    // Free tier allows only 1 group; unlock Pro for multi-group fixture.
    await library.pro.setPro(true);

    final fav = await library.createGroup('Favorites');
    final rpgs = await library.createGroup('RPGs');
    await library.addGameToGroup(fav.id, gameId);
    await library.addGameToGroup(rpgs.id, gameId);
    await library.addGameToGroup(rpgs.id, gameId2);

    final exported = await packs.exportMultiPack(
      kind: GamePackKind.full,
      gameIds: [gameId, gameId2],
    );

    // Simulate reinstall: wipe library index groups + games, keep ROM files
    // only via pack re-import.
    await library.remove(gameId);
    await library.remove(gameId2);
    for (final g in List.of(library.groups)) {
      await library.deleteGroup(g.id);
    }
    expect(library.groups, isEmpty);
    expect(library.byId(gameId), isNull);

    final result = await packs.importMultiPack(exported.tempFilePath);
    expect(result.imported, 2);
    expect(result.groups.created, 2);
    expect(result.groups.skippedCreate, 0);

    final names = library.groups.map((g) => g.name).toSet();
    expect(names, containsAll(['Favorites', 'RPGs']));

    final favRestored =
        library.groups.firstWhere((g) => g.name == 'Favorites');
    final rpgsRestored = library.groups.firstWhere((g) => g.name == 'RPGs');
    expect(favRestored.gameIds, [gameId]);
    expect(rpgsRestored.gameIds.toSet(), {gameId, gameId2});
  });

  test('single full pack restores group membership for that game', () async {
    await seedGame();
    await library.pro.setPro(true);
    final g = await library.createGroup('Handheld');
    await library.addGameToGroup(g.id, gameId);

    final exported = await packs.exportFullPack(
      gameId: gameId,
      titleForFileName: 'Test Game',
    );

    await library.remove(gameId);
    await library.deleteGroup(g.id);
    expect(library.groups, isEmpty);

    final result = await packs.importFullPack(
      zipPath: exported.tempFilePath,
      mode: GamePackImportMode.createNew,
    );
    expect(result.createdNew, isTrue);
    expect(result.groups.created, 1);
    expect(library.groups.single.name, 'Handheld');
    expect(library.groups.single.gameIds, [gameId]);
  });

  test('group restore merges into existing local group by name', () async {
    await seedGame();
    final gameId2 = await seedSecondGame();
    await library.pro.setPro(true);

    final packGroup = await library.createGroup('Shared');
    await library.addGameToGroup(packGroup.id, gameId);
    await library.addGameToGroup(packGroup.id, gameId2);

    final exported = await packs.exportMultiPack(
      kind: GamePackKind.full,
      gameIds: [gameId, gameId2],
    );

    await library.remove(gameId);
    await library.remove(gameId2);
    await library.deleteGroup(packGroup.id);

    // Local already has a differently-id'd group with the same name.
    final local = await library.createGroup('Shared');
    expect(local.id, isNot(packGroup.id));

    final result = await packs.importMultiPack(exported.tempFilePath);
    expect(result.imported, 2);
    expect(result.groups.created, 0);
    expect(library.groups.where((g) => g.name == 'Shared').length, 1);
    final merged = library.groups.singleWhere((g) => g.name == 'Shared');
    expect(merged.id, local.id);
    expect(merged.gameIds.toSet(), {gameId, gameId2});
  });

  test('multi save pack does not export or restore groups', () async {
    await seedGame();
    await library.pro.setPro(true);
    final g = await library.createGroup('OnlySaves');
    await library.addGameToGroup(g.id, gameId);

    final exported = await packs.exportMultiPack(
      kind: GamePackKind.saves,
      gameIds: [gameId],
    );
    final map = await packs.inspect(exported.tempFilePath);
    expect(map, isA<MultiPackInspect>());

    // Export must not embed groups (import alone would pass even if it did).
    final rootManifest = await _readZipManifest(exported.tempFilePath);
    expect(rootManifest.containsKey('groups'), isFalse);

    // Wipe group; save import must not recreate it.
    await library.deleteGroup(g.id);
    final result = await packs.importMultiPack(exported.tempFilePath);
    expect(result.imported, 1);
    expect(result.groups.created, 0);
    expect(library.groups, isEmpty);
  });

  test('multi full nested game manifests omit groups', () async {
    await seedGame();
    await library.pro.setPro(true);
    final g = await library.createGroup('NestedOmit');
    await library.addGameToGroup(g.id, gameId);

    final exported = await packs.exportMultiPack(
      kind: GamePackKind.full,
      gameIds: [gameId],
    );
    final root = await _readZipManifest(exported.tempFilePath);
    expect(root['groups'], isNotNull);
    expect((root['groups'] as List).length, 1);

    final nested = await _readZipManifest(
      exported.tempFilePath,
      entryPath: 'games/$gameId/manifest.json',
    );
    expect(nested.containsKey('groups'), isFalse);
  });

  test('free tier creates at most one group and skips the rest', () async {
    await seedGame();
    final gameId2 = await seedSecondGame();
    // Multi packs are Pro-only; free-tier group caps still apply on single full
    // imports. Default ProAccess is free (maxGroups = 1).
    expect(library.pro.isPro, isFalse);

    await library.pro.setPro(true);
    final a = await library.createGroup('Alpha');
    final b = await library.createGroup('Beta');
    await library.addGameToGroup(a.id, gameId);
    await library.addGameToGroup(b.id, gameId2);
    final packA = await packs.exportFullPack(
      gameId: gameId,
      titleForFileName: 'Test Game',
    );
    final packB = await packs.exportFullPack(
      gameId: gameId2,
      titleForFileName: 'Second',
    );
    await library.pro.setPro(false);

    await library.remove(gameId);
    await library.remove(gameId2);
    for (final g in List.of(library.groups)) {
      await library.deleteGroup(g.id);
    }
    expect(library.groups, isEmpty);

    final r1 = await packs.importFullPack(
      zipPath: packA.tempFilePath,
      mode: GamePackImportMode.createNew,
    );
    expect(r1.groups.created, 1);
    expect(library.groups.length, FreeLimits.maxGroups);

    final r2 = await packs.importFullPack(
      zipPath: packB.tempFilePath,
      mode: GamePackImportMode.createNew,
    );
    expect(r2.groups.created, 0);
    expect(r2.groups.skippedCreate, 1);
    expect(library.groups.length, FreeLimits.maxGroups);
  });

  test('free tier at cap merges by name without creating', () async {
    await seedGame();
    final gameId2 = await seedSecondGame();
    expect(library.pro.isPro, isFalse);

    final local = await library.createGroup('Shared');
    expect(library.canCreateGroup(), isFalse);

    // Build a pack that references a differently-id'd "Shared" group.
    await library.pro.setPro(true);
    await library.deleteGroup(local.id);
    final packGroup = await library.createGroup('Shared');
    await library.addGameToGroup(packGroup.id, gameId);
    await library.addGameToGroup(packGroup.id, gameId2);
    final pack1 = await packs.exportFullPack(
      gameId: gameId,
      titleForFileName: 'Test Game',
    );
    final pack2 = await packs.exportFullPack(
      gameId: gameId2,
      titleForFileName: 'Second',
    );

    await library.remove(gameId);
    await library.remove(gameId2);
    await library.deleteGroup(packGroup.id);
    await library.pro.setPro(false);

    // Free user already at cap with same name, different id.
    final atCap = await library.createGroup('Shared');
    expect(atCap.id, isNot(packGroup.id));
    expect(library.canCreateGroup(), isFalse);

    final r1 = await packs.importFullPack(
      zipPath: pack1.tempFilePath,
      mode: GamePackImportMode.createNew,
    );
    final r2 = await packs.importFullPack(
      zipPath: pack2.tempFilePath,
      mode: GamePackImportMode.createNew,
    );
    expect(r1.groups.created, 0);
    expect(r1.groups.skippedCreate, 0);
    expect(r1.groups.existingGroupsUpdated, 1);
    expect(r2.groups.created, 0);
    expect(r2.groups.existingGroupsUpdated, 1);
    expect(library.groups.length, 1);
    expect(library.groups.single.id, atCap.id);
    expect(library.groups.single.gameIds.toSet(), {gameId, gameId2});
  });

  test('free tier at cap with different name skips create', () async {
    await seedGame();
    expect(library.pro.isPro, isFalse);

    final local = await library.createGroup('LocalOnly');
    await library.pro.setPro(true);
    final packGroup = await library.createGroup('FromPack');
    await library.addGameToGroup(packGroup.id, gameId);
    final exported = await packs.exportFullPack(
      gameId: gameId,
      titleForFileName: 'Test Game',
    );
    await library.deleteGroup(packGroup.id);
    await library.pro.setPro(false);

    // Still at free cap with LocalOnly.
    expect(library.groups.single.id, local.id);
    expect(library.canCreateGroup(), isFalse);

    final result = await packs.importFullPack(
      zipPath: exported.tempFilePath,
      mode: GamePackImportMode.replaceExisting,
    );
    expect(result.groups.created, 0);
    expect(result.groups.skippedCreate, 1);
    expect(library.groups.map((g) => g.name).toSet(), {'LocalOnly'});
    expect(library.isGameInGroup(local.id, gameId), isFalse);
  });

  test('failed multi entry does not attach groups for that game', () async {
    await seedGame();
    final gameId2 = await seedSecondGame();
    await library.pro.setPro(true);

    final g = await library.createGroup('Both');
    await library.addGameToGroup(g.id, gameId);
    await library.addGameToGroup(g.id, gameId2);

    final exported = await packs.exportMultiPack(
      kind: GamePackKind.full,
      gameIds: [gameId, gameId2],
    );

    // Corrupt game2 tree inside the zip so its import fails, while game1
    // still imports. game2 remains absent from the library after remove.
    await library.remove(gameId);
    await library.remove(gameId2);
    await library.deleteGroup(g.id);

    final bytes = await File(exported.tempFilePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final out = Archive();
    for (final f in archive) {
      if (f.isFile && f.name == 'games/$gameId2/manifest.json') {
        out.addFile(
          ArchiveFile(
            f.name,
            2,
            utf8.encode('{}'),
          ),
        );
      } else if (f.isFile) {
        out.addFile(ArchiveFile(f.name, f.size, f.content));
      }
    }
    final corruptPath = p.join(temp.path, 'corrupt.full.multi.lemongba.zip');
    await File(corruptPath).writeAsBytes(ZipEncoder().encode(out));

    final result = await packs.importMultiPack(corruptPath);
    expect(result.imported, 1);
    expect(result.failed, 1);
    // Only the successfully imported game may be attached to restored groups.
    expect(library.byId(gameId), isNotNull);
    expect(library.byId(gameId2), isNull);
    final restored = library.groups.where((x) => x.name == 'Both').toList();
    expect(restored, isNotEmpty);
    expect(restored.single.gameIds, [gameId]);
  });
}

Future<Map<String, dynamic>> _readZipManifest(
  String zipPath, {
  String entryPath = 'manifest.json',
}) async {
  final bytes = await File(zipPath).readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes);
  final file = archive.findFile(entryPath);
  expect(file, isNotNull, reason: 'missing $entryPath in $zipPath');
  final decoded = jsonDecode(utf8.decode(file!.content as List<int>));
  expect(decoded, isA<Map>());
  return Map<String, dynamic>.from(decoded as Map);
}
