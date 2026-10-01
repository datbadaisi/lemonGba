import '../../core/storage/game_pack_port.dart';

/// Manifest format constants and pure parse/build helpers.
abstract final class PackManifest {
  static const singleFormat = 'lemongba.pack';
  static const multiFormat = 'lemongba.multi.pack';
  static const version = 1;
  static const appVersion = '1.0.0+7';

  static Map<String, dynamic> buildSingle({
    required GamePackKind kind,
    required String gameId,
    required String title,
    required List<Map<String, dynamic>> files,
    String? romFileName,
    String? romExtension,
    List<Map<String, dynamic>>? groups,
  }) {
    return {
      'format': singleFormat,
      'version': version,
      'kind': kind == GamePackKind.saves ? 'saves' : 'full',
      'gameId': gameId,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': appVersion,
      'title': title,
      'romFileName': ?romFileName,
      'romExtension': ?romExtension,
      'files': files,
      if (groups != null && groups.isNotEmpty) 'groups': groups,
    };
  }

  static Map<String, dynamic> buildMulti({
    required GamePackKind kind,
    required List<Map<String, dynamic>> games,
    List<Map<String, dynamic>>? groups,
  }) {
    return {
      'format': multiFormat,
      'version': version,
      'kind': kind == GamePackKind.saves ? 'saves' : 'full',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': appVersion,
      'gameCount': games.length,
      'games': games,
      if (groups != null && groups.isNotEmpty) 'groups': groups,
    };
  }

  /// Optional pack group folders (`id` / `name` / `createdAt` / `gameIds`).
  ///
  /// Present on full packs only. Missing/invalid entries are ignored so older
  /// packs without groups still import cleanly.
  static List<Map<String, dynamic>> parseGroups(Object? raw) {
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final item in raw) {
      Map<String, dynamic>? map;
      if (item is Map<String, dynamic>) {
        map = item;
      } else if (item is Map) {
        map = Map<String, dynamic>.from(item);
      }
      if (map == null) continue;
      final id = (map['id'] as String?)?.trim() ?? '';
      final name = (map['name'] as String?)?.trim() ?? '';
      if (id.isEmpty && name.isEmpty) continue;
      // Dedup by id when present; nameless+idless already skipped.
      final dedupeKey = id.isNotEmpty ? 'id:$id' : 'name:${name.toLowerCase()}';
      if (!seen.add(dedupeKey)) continue;
      out.add(map);
    }
    return out;
  }

  static GamePackKind parseKind(Object? kindStr, {required bool multi}) {
    final kind = switch (kindStr) {
      'saves' => GamePackKind.saves,
      'full' => GamePackKind.full,
      _ => null,
    };
    if (kind == null) {
      throw GamePackException(
        GamePackErrorCode.invalidFormat,
        multi ? 'Invalid multi pack kind' : 'Invalid pack kind',
      );
    }
    return kind;
  }

  static int parseVersion(Object? version) {
    final ver = version is int
        ? version
        : (version is num ? version.toInt() : int.tryParse('$version'));
    if (ver != PackManifest.version) {
      throw const GamePackException(
        GamePackErrorCode.unsupportedVersion,
        'Unsupported pack version',
      );
    }
    return ver ?? PackManifest.version;
  }

  static DateTime parseExportedAt(Object? raw) {
    return DateTime.tryParse(raw as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static List<Map<String, dynamic>> parseFiles(Object? filesRaw) {
    final files = <Map<String, dynamic>>[];
    if (filesRaw is! List) return files;
    for (final item in filesRaw) {
      if (item is Map<String, dynamic>) {
        files.add(item);
      } else if (item is Map) {
        files.add(Map<String, dynamic>.from(item));
      }
    }
    return files;
  }

  static ({GamePackInfo info, List<Map<String, dynamic>> files})
      parseSingle(Map<String, dynamic> map) {
    if (map['format'] != singleFormat) {
      throw const GamePackException(
        GamePackErrorCode.invalidFormat,
        'Not a Lemon pack',
      );
    }
    final ver = parseVersion(map['version']);
    final kind = parseKind(map['kind'], multi: false);
    final gameId = map['gameId'] as String?;
    if (gameId == null || gameId.isEmpty) {
      throw const GamePackException(
        GamePackErrorCode.invalidFormat,
        'Missing gameId',
      );
    }
    return (
      info: GamePackInfo(
        kind: kind,
        gameId: gameId,
        exportedAt: parseExportedAt(map['exportedAt']),
        title: map['title'] as String?,
        formatVersion: ver,
      ),
      files: parseFiles(map['files']),
    );
  }

  static MultiGamePackInfo parseMulti(Map<String, dynamic> map) {
    if (map['format'] != multiFormat) {
      throw const GamePackException(
        GamePackErrorCode.invalidFormat,
        'Not a multi Lemon pack',
      );
    }
    final ver = parseVersion(map['version']);
    final kind = parseKind(map['kind'], multi: true);
    final gamesRaw = map['games'];
    if (gamesRaw is! List || gamesRaw.isEmpty) {
      throw const GamePackException(
        GamePackErrorCode.invalidFormat,
        'Multi pack has no games',
      );
    }

    final games = <MultiGamePackEntry>[];
    for (final item in gamesRaw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final gameId = m['gameId'] as String?;
      // Flat multi: `root` is the directory prefix. Legacy nested packs used
      // `pack` (path to a nested zip) — reject those as unsupported.
      final rootRaw = (m['root'] as String?)?.replaceAll('\\', '/');
      if (gameId == null || gameId.isEmpty || rootRaw == null || rootRaw.isEmpty) {
        if (m['pack'] != null) {
          throw const GamePackException(
            GamePackErrorCode.unsupportedVersion,
            'Legacy nested multi packs are not supported — re-export multi pack',
          );
        }
        continue;
      }
      var root = rootRaw.replaceAll(RegExp(r'/+$'), '');
      if (root.contains('..') || root.startsWith('/')) {
        throw const GamePackException(
          GamePackErrorCode.corruptEntry,
          'Unsafe path in multi pack',
        );
      }
      // Normalize: no leading slash; refuse absolute Windows-style.
      if (root.contains(':')) {
        throw const GamePackException(
          GamePackErrorCode.corruptEntry,
          'Unsafe path in multi pack',
        );
      }
      games.add(
        MultiGamePackEntry(
          gameId: gameId,
          root: root,
          title: m['title'] as String?,
        ),
      );
    }
    if (games.isEmpty) {
      throw const GamePackException(
        GamePackErrorCode.invalidFormat,
        'Multi pack has no valid game entries',
      );
    }

    return MultiGamePackInfo(
      kind: kind,
      exportedAt: parseExportedAt(map['exportedAt']),
      games: games,
      formatVersion: ver,
    );
  }

  static String? findRolePath(List<Map<String, dynamic>> files, String role) {
    for (final f in files) {
      if (f['role'] == role) {
        final path = f['path'] as String?;
        if (path != null && path.isNotEmpty) {
          return path.replaceAll('\\', '/');
        }
      }
    }
    return null;
  }
}
