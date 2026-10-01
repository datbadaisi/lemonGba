import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/entitlements/free_limits.dart';
import '../../core/storage/game_pack_port.dart';
import '../../core/storage/safe_file_stem.dart';
import '../library/game_library.dart';
import '../library/rom_identity.dart';
import 'pack_manifest.dart';
import 'pack_zip_io.dart';
import 'play_data_pack_swap.dart';
import 'save_paths.dart';

/// Zip-based implementation of [GamePackPort].
///
/// Second privileged writer of play-data paths (alongside session save I/O).
/// See docs/architecture.md dual-writer note.
///
/// **Multi packs** are a flat multi-root archive: one `games/<gameId>/` tree
/// per title (same layout as a single pack), not nested zip files.
class ZipGamePackService implements GamePackPort {
  ZipGamePackService({required this.paths, required this.library})
    : _io = PackZipIo(paths.packsTempDir),
      _swap = PlayDataPackSwap(paths);

  final SavePaths paths;
  final GameLibrary library;
  final PackZipIo _io;
  final PlayDataPackSwap _swap;

  /// Complete crash recovery before the home screen can open a game.
  Future<void> recoverInterruptedSwaps() => _swap.recoverInterruptedSwaps();

  @override
  Future<GamePackExportResult> exportSavePack({
    required String gameId,
    required String titleForFileName,
  }) async {
    final gathered = await _gatherSaveMembers(
      gameId: gameId,
      title: titleForFileName,
    );
    return _io.encodeZip(
      kind: GamePackKind.saves,
      suggestedFileName: packSuggestedFileName(
        title: titleForFileName,
        fullPack: false,
      ),
      manifest: gathered.manifest,
      members: gathered.members,
    );
  }

  @override
  Future<GamePackExportResult> exportFullPack({
    required String gameId,
    required String titleForFileName,
  }) async {
    final gathered = await _gatherFullMembers(
      gameId: gameId,
      title: titleForFileName,
    );
    return _io.encodeZip(
      kind: GamePackKind.full,
      suggestedFileName: packSuggestedFileName(
        title: titleForFileName,
        fullPack: true,
      ),
      manifest: gathered.manifest,
      members: gathered.members,
    );
  }

  @override
  Future<GamePackExportResult> exportMultiPack({
    required GamePackKind kind,
    required List<String> gameIds,
  }) async {
    if (!library.pro.isPro) {
      throw const FreeTierLimitException(FreeTierMessages.multiBackup);
    }
    final ids = gameIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) {
      throw const GamePackException(
        GamePackErrorCode.invalidFormat,
        'Select at least one game',
      );
    }

    final members = <PackZipMember>[];
    final gamesMeta = <Map<String, dynamic>>[];
    final tempMeta = <File>[];

    try {
      for (final gameId in ids) {
        final game = library.byId(gameId);
        if (game == null) {
          throw const GamePackException(
            GamePackErrorCode.gameNotInLibrary,
            'Game not in library',
          );
        }

        // Nested multi trees omit groups — multi root manifest is the sole
        // group source so import never double-applies membership.
        final gathered = kind == GamePackKind.saves
            ? await _gatherSaveMembers(gameId: gameId, title: game.title)
            : await _gatherFullMembers(
                gameId: gameId,
                title: game.title,
                includeGroups: false,
              );

        final root = 'games/$gameId';
        for (final m in gathered.members) {
          members.add(m.withPrefix(root));
        }

        // Per-game single-style manifest for import without re-zipping.
        final gameManifestTemp = await _io.writeTempText(
          'game_manifest_${gameId.length > 12 ? gameId.substring(0, 12) : gameId}.json',
          const JsonEncoder.withIndent('  ').convert(gathered.manifest),
        );
        tempMeta.add(gameManifestTemp);
        members.add(
          PackZipMember(file: gameManifestTemp, zipPath: '$root/manifest.json'),
        );

        gamesMeta.add({'gameId': gameId, 'title': game.title, 'root': root});
      }

      // Full multi packs embed group folders that touch any selected game
      // (membership filtered to the pack’s game set). Save packs omit groups.
      final groupsMeta = kind == GamePackKind.full
          ? _groupsJsonForGameIds(ids.toSet())
          : null;

      return await _io.encodeZip(
        kind: kind,
        suggestedFileName: multiPackSuggestedFileName(
          gameCount: gamesMeta.length,
          fullPack: kind == GamePackKind.full,
        ),
        manifest: PackManifest.buildMulti(
          kind: kind,
          games: gamesMeta,
          groups: groupsMeta,
        ),
        members: members,
      );
    } finally {
      for (final f in tempMeta) {
        await PackZipIo.deleteFileQuietly(f);
      }
    }
  }

  @override
  Future<PackInspectResult> inspect(String zipPath) async {
    final map = await _io.readManifestMap(zipPath);
    final format = map['format'];
    if (format == PackManifest.multiFormat) {
      return MultiPackInspect(PackManifest.parseMulti(map));
    }
    if (format == PackManifest.singleFormat) {
      return SinglePackInspect(PackManifest.parseSingle(map).info);
    }
    throw const GamePackException(
      GamePackErrorCode.invalidFormat,
      'Not a Lemon pack',
    );
  }

  @override
  Future<GamePackImportResult> importSavePack({
    required String zipPath,
    required String expectedGameId,
  }) async {
    final map = await _io.readManifestMap(zipPath);
    final parsed = PackManifest.parseSingle(map);
    if (parsed.info.kind != GamePackKind.saves) {
      throw const GamePackException(
        GamePackErrorCode.wrongKind,
        'Expected a save pack',
      );
    }
    if (parsed.info.gameId != expectedGameId) {
      throw const GamePackException(
        GamePackErrorCode.wrongGame,
        'This pack belongs to a different game',
      );
    }
    if (library.byId(expectedGameId) == null) {
      throw const GamePackException(
        GamePackErrorCode.gameNotInLibrary,
        'Game not in library',
      );
    }

    final stageDir = await _io.extractZipToStage(zipPath);
    try {
      await _validateDeclaredFiles(stageDir, parsed.files);
      await _swap.applyFromStage(gameId: expectedGameId, stageDir: stageDir);
      return GamePackImportResult(
        gameId: expectedGameId,
        kind: GamePackKind.saves,
        createdNew: false,
        title: parsed.info.title,
      );
    } finally {
      await PackZipIo.deleteDirQuietly(stageDir);
    }
  }

  @override
  Future<GamePackImportResult> importFullPack({
    required String zipPath,
    required GamePackImportMode mode,
  }) async {
    final map = await _io.readManifestMap(zipPath);
    final parsed = PackManifest.parseSingle(map);
    if (parsed.info.kind != GamePackKind.full) {
      throw const GamePackException(
        GamePackErrorCode.wrongKind,
        'Expected a full pack',
      );
    }

    final stageDir = await _io.extractZipToStage(zipPath);
    try {
      return await _applyFullFromStage(
        stageDir: stageDir,
        files: parsed.files,
        info: parsed.info,
        mode: mode,
        packGroups: map['groups'],
      );
    } finally {
      await PackZipIo.deleteDirQuietly(stageDir);
    }
  }

  @override
  Future<MultiGamePackImportResult> importMultiPack(String zipPath) async {
    if (!library.pro.isPro) {
      throw const FreeTierLimitException(FreeTierMessages.multiBackup);
    }
    final map = await _io.readManifestMap(zipPath);
    final info = PackManifest.parseMulti(map);
    final stageDir = await _io.extractZipToStage(zipPath);
    final entries = <MultiGamePackEntryResult>[];

    try {
      for (final entry in info.games) {
        entries.add(await _importMultiEntry(stageDir, info.kind, entry));
      }

      var groups = GroupPackRestoreResult.empty;
      if (info.kind == GamePackKind.full) {
        // Only attach groups for entries that actually imported this run —
        // not every pack id that happens to already be in the library after a
        // failed replace (avoids mutating groups on failed titles).
        final relevant = {
          for (final e in entries)
            if (e.status == MultiGamePackEntryStatus.imported) e.gameId,
        };
        groups = await _restoreGroupsFromManifest(
          map['groups'],
          relevantGameIds: relevant,
        );
      }

      return MultiGamePackImportResult(
        kind: info.kind,
        entries: entries,
        groups: groups,
      );
    } finally {
      await PackZipIo.deleteDirQuietly(stageDir);
    }
  }

  Future<MultiGamePackEntryResult> _importMultiEntry(
    Directory stageDir,
    GamePackKind kind,
    MultiGamePackEntry entry,
  ) async {
    final title = entry.title;
    try {
      final gameRoot = _resolveGameRoot(stageDir, entry.root);
      if (!await gameRoot.exists()) {
        return MultiGamePackEntryResult(
          gameId: entry.gameId,
          title: title,
          status: MultiGamePackEntryStatus.failed,
          errorCode: GamePackErrorCode.corruptEntry,
          errorMessage: 'Missing game tree in pack',
        );
      }

      if (kind == GamePackKind.saves) {
        if (library.byId(entry.gameId) == null) {
          return MultiGamePackEntryResult(
            gameId: entry.gameId,
            title: title,
            status: MultiGamePackEntryStatus.skipped,
          );
        }
        final gameMap = await _io.readManifestMapFromDir(gameRoot);
        final parsed = PackManifest.parseSingle(gameMap);
        if (parsed.info.kind != GamePackKind.saves ||
            parsed.info.gameId != entry.gameId) {
          throw const GamePackException(
            GamePackErrorCode.corruptEntry,
            'Save pack tree does not match its game entry',
          );
        }
        await _validateDeclaredFiles(gameRoot, parsed.files);
        await _swap.applyFromStage(gameId: entry.gameId, stageDir: gameRoot);
        return MultiGamePackEntryResult(
          gameId: entry.gameId,
          title: title,
          status: MultiGamePackEntryStatus.imported,
        );
      }

      // Full: auto create/replace from library.
      final mode = library.byId(entry.gameId) != null
          ? GamePackImportMode.replaceExisting
          : GamePackImportMode.createNew;

      final gameMap = await _io.readManifestMapFromDir(gameRoot);
      final parsed = PackManifest.parseSingle(gameMap);
      if (parsed.info.kind != GamePackKind.full) {
        return MultiGamePackEntryResult(
          gameId: entry.gameId,
          title: title,
          status: MultiGamePackEntryStatus.failed,
          errorCode: GamePackErrorCode.wrongKind,
          errorMessage: 'Expected a full pack tree',
        );
      }
      if (parsed.info.gameId != entry.gameId) {
        return MultiGamePackEntryResult(
          gameId: entry.gameId,
          title: title,
          status: MultiGamePackEntryStatus.failed,
          errorCode: GamePackErrorCode.corruptEntry,
          errorMessage: 'Game id mismatch in pack tree',
        );
      }

      // Groups are restored once for the whole multi pack — not per tree.
      final result = await _applyFullFromStage(
        stageDir: gameRoot,
        files: parsed.files,
        info: parsed.info,
        mode: mode,
        packGroups: null,
      );
      return MultiGamePackEntryResult(
        gameId: result.gameId,
        title: result.title ?? title,
        status: MultiGamePackEntryStatus.imported,
        createdNew: result.createdNew,
        skippedAvatar: result.skippedAvatar,
        skippedCover: result.skippedCover,
      );
    } on GamePackException catch (e) {
      return MultiGamePackEntryResult(
        gameId: entry.gameId,
        title: title,
        status: MultiGamePackEntryStatus.failed,
        errorCode: e.code,
        errorMessage: e.message,
      );
    } catch (e) {
      return MultiGamePackEntryResult(
        gameId: entry.gameId,
        title: title,
        status: MultiGamePackEntryStatus.failed,
        errorCode: GamePackErrorCode.ioFailure,
        errorMessage: e.toString(),
      );
    }
  }

  Directory _resolveGameRoot(Directory stageDir, String root) {
    final rel = root.replaceAll('\\', '/').replaceAll(RegExp(r'^/+|/+$'), '');
    if (rel.contains('..') || rel.contains(':') || p.isAbsolute(rel)) {
      throw const GamePackException(
        GamePackErrorCode.corruptEntry,
        'Unsafe path in multi pack',
      );
    }
    final dir = Directory(p.join(stageDir.path, rel));
    final outCanon = p.canonicalize(dir.path);
    final stageCanon = p.canonicalize(stageDir.path);
    if (!outCanon.startsWith(stageCanon)) {
      throw const GamePackException(
        GamePackErrorCode.corruptEntry,
        'Zip-slip path rejected',
      );
    }
    return dir;
  }

  // ── Member gathering ─────────────────────────────────────────────────────

  /// An intentionally empty save pack has no declared files. A pack that
  /// declares a file but omits it must fail before replacing live play data.
  Future<void> _validateDeclaredFiles(
    Directory stageDir,
    List<Map<String, dynamic>> files,
  ) async {
    for (final entry in files) {
      final raw = entry['path'];
      if (raw is! String || raw.isEmpty) {
        throw const GamePackException(
          GamePackErrorCode.corruptEntry,
          'Invalid file path in pack manifest',
        );
      }
      final rel = raw.replaceAll('\\', '/');
      final segments = rel.split('/');
      if (rel.startsWith('/') ||
          rel.contains(':') ||
          segments.any((s) => s.isEmpty || s == '.' || s == '..')) {
        throw const GamePackException(
          GamePackErrorCode.corruptEntry,
          'Unsafe file path in pack manifest',
        );
      }
      final file = File(p.join(stageDir.path, rel));
      if (!await file.exists()) {
        throw GamePackException(
          GamePackErrorCode.corruptEntry,
          'Pack is missing declared file: $rel',
        );
      }
    }
  }

  Future<({List<PackZipMember> members, Map<String, dynamic> manifest})>
  _gatherSaveMembers({required String gameId, required String title}) async {
    await paths.ensureDirs();
    await paths.ensureStateDir(gameId);
    await paths.migrateLegacyQuickSaveIfNeeded(gameId);

    final members = <PackZipMember>[];
    final fileEntries = <Map<String, dynamic>>[];

    for (final m in paths.playDataMembersForGame(gameId)) {
      final f = File(m.absolutePath);
      if (!await f.exists()) continue;
      members.add(PackZipMember(file: f, zipPath: m.zipPath));
      fileEntries.add({
        'path': m.zipPath,
        'role': m.role,
        if (m.slot != null) 'slot': m.slot,
      });
    }

    return (
      members: members,
      manifest: PackManifest.buildSingle(
        kind: GamePackKind.saves,
        gameId: gameId,
        title: title,
        files: fileEntries,
      ),
    );
  }

  Future<({List<PackZipMember> members, Map<String, dynamic> manifest})>
  _gatherFullMembers({
    required String gameId,
    required String title,
    bool includeGroups = true,
  }) async {
    await paths.ensureDirs();
    await paths.ensureStateDir(gameId);
    await paths.migrateLegacyQuickSaveIfNeeded(gameId);

    final game = library.byId(gameId);
    if (game == null) {
      throw const GamePackException(
        GamePackErrorCode.gameNotInLibrary,
        'Game not in library',
      );
    }

    final rom = File(library.romPathOf(game));
    if (!await rom.exists()) {
      throw const GamePackException(
        GamePackErrorCode.romMissing,
        'ROM file missing — cannot export full pack',
      );
    }

    final ext = p.extension(game.romFileName).toLowerCase();
    final romZipName = 'rom/game${ext.isEmpty ? '.gba' : ext}';

    final members = <PackZipMember>[
      PackZipMember(file: rom, zipPath: romZipName),
    ];
    final fileEntries = <Map<String, dynamic>>[
      {'path': romZipName, 'role': 'rom'},
    ];

    final short = gameId.length >= 12 ? gameId.substring(0, 12) : gameId;
    final metaTemp = await _io.writeTempText(
      'library_entry_$short.json',
      jsonEncode(game.toJson()),
    );
    members.add(
      PackZipMember(file: metaTemp, zipPath: 'meta/library_entry.json'),
    );
    fileEntries.add({
      'path': 'meta/library_entry.json',
      'role': 'library_entry',
    });

    final avatarName = game.avatarFileName;
    if (avatarName != null && avatarName.isNotEmpty) {
      final av = File(paths.coverPathForFileName(avatarName));
      if (await av.exists()) {
        final aext = p.extension(avatarName).toLowerCase();
        final z = 'art/avatar${aext.isEmpty ? '.png' : aext}';
        members.add(PackZipMember(file: av, zipPath: z));
        fileEntries.add({'path': z, 'role': 'avatar'});
      }
    }
    final coverName = game.coverFileName;
    if (coverName != null && coverName.isNotEmpty) {
      final cv = File(paths.coverPathForFileName(coverName));
      if (await cv.exists()) {
        final cext = p.extension(coverName).toLowerCase();
        final z = 'art/cover${cext.isEmpty ? '.png' : cext}';
        members.add(PackZipMember(file: cv, zipPath: z));
        fileEntries.add({'path': z, 'role': 'cover'});
      }
    }

    for (final m in paths.playDataMembersForGame(gameId)) {
      final f = File(m.absolutePath);
      if (!await f.exists()) continue;
      members.add(PackZipMember(file: f, zipPath: m.zipPath));
      fileEntries.add({
        'path': m.zipPath,
        'role': m.role,
        if (m.slot != null) 'slot': m.slot,
      });
    }

    return (
      members: members,
      manifest: PackManifest.buildSingle(
        kind: GamePackKind.full,
        gameId: gameId,
        title: title,
        files: fileEntries,
        romFileName: game.romFileName,
        romExtension: ext.isEmpty ? '.gba' : ext,
        groups: includeGroups ? _groupsJsonForGameIds({gameId}) : null,
      ),
    );
  }

  /// Groups that contain any of [gameIds], with membership filtered to that set.
  List<Map<String, dynamic>>? _groupsJsonForGameIds(Set<String> gameIds) {
    if (gameIds.isEmpty) return null;
    final out = <Map<String, dynamic>>[];
    for (final g in library.groups) {
      final members = g.gameIds.where(gameIds.contains).toList();
      if (members.isEmpty) continue;
      out.add({
        'id': g.id,
        'name': g.name,
        'createdAt': g.createdAt.toIso8601String(),
        'gameIds': members,
      });
    }
    return out.isEmpty ? null : out;
  }

  Future<GroupPackRestoreResult> _restoreGroupsFromManifest(
    Object? rawGroups, {
    required Set<String> relevantGameIds,
  }) async {
    final packGroups = PackManifest.parseGroups(rawGroups);
    if (packGroups.isEmpty || relevantGameIds.isEmpty) {
      return GroupPackRestoreResult.empty;
    }
    final r = await library.mergeGroupsFromPack(
      packGroups,
      relevantGameIds: relevantGameIds,
    );
    return GroupPackRestoreResult(
      created: r.created,
      membershipUpdated: r.membershipUpdated,
      existingGroupsUpdated: r.existingGroupsUpdated,
      skippedCreate: r.skippedCreate,
    );
  }

  // ── Full apply from staged single-game tree ──────────────────────────────

  Future<GamePackImportResult> _applyFullFromStage({
    required Directory stageDir,
    required List<Map<String, dynamic>> files,
    required GamePackInfo info,
    required GamePackImportMode mode,
    Object? packGroups,
  }) async {
    await _validateDeclaredFiles(stageDir, files);
    if (mode != GamePackImportMode.createNew &&
        mode != GamePackImportMode.replaceExisting) {
      throw const GamePackException(
        GamePackErrorCode.modeMismatch,
        'Invalid full-pack import mode',
      );
    }

    final gameId = info.gameId;
    final existing = library.byId(gameId);
    if (mode == GamePackImportMode.createNew && existing != null) {
      throw const GamePackException(
        GamePackErrorCode.modeMismatch,
        'Game already exists — use replaceExisting',
      );
    }
    if (mode == GamePackImportMode.replaceExisting && existing == null) {
      throw const GamePackException(
        GamePackErrorCode.modeMismatch,
        'Game not in library — use createNew',
      );
    }

    final romRel =
        PackManifest.findRolePath(files, 'rom') ??
        await _findFirstRomInStage(stageDir);
    if (romRel == null) {
      throw const GamePackException(
        GamePackErrorCode.corruptEntry,
        'Pack is missing ROM',
      );
    }
    final stagedRom = File(p.join(stageDir.path, romRel));
    if (!await stagedRom.exists()) {
      throw const GamePackException(
        GamePackErrorCode.corruptEntry,
        'Pack ROM file missing',
      );
    }
    final romExt = p.extension(stagedRom.path).toLowerCase();
    if (romExt != '.gba' && romExt != '.bin') {
      throw const GamePackException(
        GamePackErrorCode.corruptEntry,
        'ROM must be .gba or .bin',
      );
    }

    final hash = (await RomIdentity.fromFile(stagedRom)).value;
    if (hash != gameId) {
      throw const GamePackException(
        GamePackErrorCode.corruptEntry,
        'ROM hash does not match pack game id',
      );
    }

    Map<String, dynamic> meta = {};
    final metaRel =
        PackManifest.findRolePath(files, 'library_entry') ??
        'meta/library_entry.json';
    final metaFile = File(p.join(stageDir.path, metaRel));
    if (await metaFile.exists()) {
      try {
        final decoded = jsonDecode(await metaFile.readAsString());
        if (decoded is Map<String, dynamic>) {
          meta = decoded;
        } else if (decoded is Map) {
          meta = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        throw const GamePackException(
          GamePackErrorCode.corruptEntry,
          'Invalid library_entry.json',
        );
      }
      final metaId = meta['id'] as String?;
      if (metaId != null && metaId.isNotEmpty && metaId != gameId) {
        throw const GamePackException(
          GamePackErrorCode.corruptEntry,
          'library_entry id does not match pack game id',
        );
      }
    }

    String? stagedAvatar;
    String? stagedCover;
    final avRel = PackManifest.findRolePath(files, 'avatar');
    if (avRel != null) {
      final f = File(p.join(stageDir.path, avRel));
      if (await f.exists()) stagedAvatar = f.path;
    } else {
      stagedAvatar = await _findArt(stageDir, 'avatar');
    }
    final cvRel = PackManifest.findRolePath(files, 'cover');
    if (cvRel != null) {
      final f = File(p.join(stageDir.path, cvRel));
      if (await f.exists()) stagedCover = f.path;
    } else {
      stagedCover = await _findArt(stageDir, 'cover');
    }

    DateTime? packAddedAt;
    DateTime? packLastPlayedAt;
    final addedRaw = meta['addedAt'] as String?;
    if (addedRaw != null) packAddedAt = DateTime.tryParse(addedRaw);
    final playedRaw = meta['lastPlayedAt'] as String?;
    if (playedRaw != null) packLastPlayedAt = DateTime.tryParse(playedRaw);

    final install = await library.installOrReplaceFromPack(
      gameId: gameId,
      stagedRomPath: stagedRom.path,
      libraryEntryJson: meta,
      stagedAvatarPath: stagedAvatar,
      stagedCoverPath: stagedCover,
      replaceExisting: mode == GamePackImportMode.replaceExisting,
      packAddedAt: packAddedAt,
      packLastPlayedAt: packLastPlayedAt,
      packTitleHint: info.title,
    );

    await _swap.applyFromStage(gameId: gameId, stageDir: stageDir);

    // Single full packs restore groups here. Multi full packs restore once
    // at the end of [importMultiPack] (pass packGroups: null from multi trees).
    final groups = await _restoreGroupsFromManifest(
      packGroups,
      relevantGameIds: {gameId},
    );

    return GamePackImportResult(
      gameId: gameId,
      kind: GamePackKind.full,
      createdNew: install.createdNew,
      skippedAvatar: install.skippedAvatar,
      skippedCover: install.skippedCover,
      title: install.game.title,
      groups: groups,
    );
  }

  Future<String?> _findFirstRomInStage(Directory stage) async {
    final romDir = Directory(p.join(stage.path, 'rom'));
    if (!await romDir.exists()) return null;
    await for (final e in romDir.list(followLinks: false)) {
      if (e is File) {
        final ext = p.extension(e.path).toLowerCase();
        if (ext == '.gba' || ext == '.bin') {
          return p.relative(e.path, from: stage.path).replaceAll('\\', '/');
        }
      }
    }
    return null;
  }

  Future<String?> _findArt(Directory stage, String base) async {
    final artDir = Directory(p.join(stage.path, 'art'));
    if (!await artDir.exists()) return null;
    await for (final e in artDir.list(followLinks: false)) {
      if (e is File) {
        final name = p.basenameWithoutExtension(e.path).toLowerCase();
        if (name == base) return e.path;
      }
    }
    return null;
  }
}
