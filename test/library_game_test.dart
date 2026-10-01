import 'package:flutter_test/flutter_test.dart';
import 'package:gba_emulator/models/game_group.dart';
import 'package:gba_emulator/models/library_game.dart';
import 'package:gba_emulator/services/game_library.dart';

void main() {
  group('GameGroup', () {
    test('json round-trip preserves order of gameIds', () {
      final g = GameGroup(
        id: 'grp_1',
        name: 'Pokémon',
        createdAt: DateTime.utc(2025, 1, 2, 3),
        gameIds: const ['a', 'b', 'c'],
      );
      final copy = GameGroup.fromJson(g.toJson());
      expect(copy.id, 'grp_1');
      expect(copy.name, 'Pokémon');
      expect(copy.gameIds, ['a', 'b', 'c']);
      expect(copy.createdAt, DateTime.utc(2025, 1, 2, 3));
      expect(copy.gameCount, 3);
    });

    test('fromJson trims empty name and skips blank ids', () {
      final g = GameGroup.fromJson({
        'id': 'x',
        'name': '  ',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'gameIds': ['ok', '', 12, null, 'two'],
      });
      expect(g.name, 'Group');
      expect(g.gameIds, ['ok', 'two']);
    });

    test('copyWith replaces gameIds list', () {
      final g = GameGroup(
        id: 'g',
        name: 'A',
        createdAt: DateTime.utc(2024, 1, 1),
        gameIds: const ['1'],
      );
      final next = g.copyWith(name: 'B', gameIds: const ['1', '2']);
      expect(next.name, 'B');
      expect(next.gameIds, ['1', '2']);
      expect(next.id, 'g');
    });
  });

  group('LibraryGame', () {
    test('title prefers user displayName over headerTitle', () {
      final g = LibraryGame(
        id: 'abc',
        displayName: 'My Emerald',
        romFileName: 'abc_rom.gba',
        addedAt: DateTime.utc(2024, 1, 1),
        headerTitle: 'POKEMON EMER',
      );
      expect(g.title, 'My Emerald');
      expect(g.monogram.length, inInclusiveRange(1, 2));
    });

    test('json round-trip includes description and art files', () {
      final g = LibraryGame(
        id: 'id1',
        displayName: 'Demo',
        romFileName: 'x.gba',
        addedAt: DateTime.utc(2025, 1, 1),
        description: 'A fun game',
        avatarFileName: 'id1_avatar.png',
        coverFileName: 'id1_cover.jpg',
      );
      final copy = LibraryGame.fromJson(g.toJson());
      expect(copy.description, 'A fun game');
      expect(copy.avatarFileName, 'id1_avatar.png');
      expect(copy.coverFileName, 'id1_cover.jpg');
    });

    test('monogram from multi-word display name', () {
      final g = LibraryGame(
        id: 'x',
        displayName: 'Fire Red',
        romFileName: 'x.gba',
        addedAt: DateTime.utc(2024, 1, 1),
      );
      expect(g.monogram, 'FR');
    });

    test('json round-trip', () {
      final g = LibraryGame(
        id: 'deadbeef',
        displayName: 'Demo',
        romFileName: 'deadbeef_Demo.gba',
        addedAt: DateTime.utc(2025, 6, 1, 12),
        lastPlayedAt: DateTime.utc(2025, 6, 2, 12),
        playTimeSeconds: 3725,
        headerTitle: 'DEMO',
      );
      final copy = LibraryGame.fromJson(g.toJson());
      expect(copy.id, g.id);
      expect(copy.displayName, g.displayName);
      expect(copy.romFileName, g.romFileName);
      expect(copy.headerTitle, 'DEMO');
      expect(copy.lastPlayedAt, g.lastPlayedAt);
      expect(copy.playTimeSeconds, 3725);
    });

    test('playTimeLabel formats hours and minutes', () {
      expect(LibraryGame.formatPlayTimeSeconds(0), '0m');
      expect(LibraryGame.formatPlayTimeSeconds(45), '<1m');
      expect(LibraryGame.formatPlayTimeSeconds(60), '1m');
      expect(LibraryGame.formatPlayTimeSeconds(125), '2m');
      expect(LibraryGame.formatPlayTimeSeconds(3600), '1h');
      expect(LibraryGame.formatPlayTimeSeconds(3725), '1h 02m');
      final g = LibraryGame(
        id: 'x',
        displayName: 'A',
        romFileName: 'x.gba',
        addedAt: DateTime.utc(2024, 1, 1),
        playTimeSeconds: 90,
      );
      expect(g.playTimeLabel, '1m');
    });

    test('parsePlayTimeSeconds coerces json / pack values', () {
      expect(LibraryGame.parsePlayTimeSeconds(null), 0);
      expect(LibraryGame.parsePlayTimeSeconds(-3), 0);
      expect(LibraryGame.parsePlayTimeSeconds(42), 42);
      expect(LibraryGame.parsePlayTimeSeconds(12.9), 12);
      expect(LibraryGame.parsePlayTimeSeconds('99'), 99);
      expect(LibraryGame.parsePlayTimeSeconds(' 7 '), 7);
      expect(LibraryGame.parsePlayTimeSeconds('nope'), 0);
      expect(LibraryGame.parsePlayTimeSeconds(true), 0);
    });
  });

  group('GameLibrary helpers', () {
    test('isAllowedRomName', () {
      expect(GameLibrary.isAllowedRomName('game.gba'), isTrue);
      expect(GameLibrary.isAllowedRomName('game.GBA'), isTrue);
      expect(GameLibrary.isAllowedRomName('game.bin'), isTrue);
      expect(GameLibrary.isAllowedRomName('game.zip'), isFalse);
      expect(GameLibrary.isAllowedRomName('game'), isFalse);
    });
  });
}
