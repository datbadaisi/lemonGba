part of 'game_library.dart';

/// Full-pack install / replace. Mixed into [GameLibrary].
/// Depends on [GameLibraryArt] for thumbs / paint paths / free-tier counts.
mixin GameLibraryPack on GameLibraryArt {
  /// Install or refresh a library row from a staged full pack (ROM + meta + art).
  ///
  /// Does **not** apply play data — pack service owns atomic savestate /
  /// cartridge swap. Path fields inside [libraryEntryJson] are ignored as
  /// filesystem sources; only [stagedRomPath] / staged art paths are used.
  Future<
      ({
        LibraryGame game,
        bool createdNew,
        bool skippedAvatar,
        bool skippedCover,
      })> installOrReplaceFromPack({
    required String gameId,
    required String stagedRomPath,
    required Map<String, dynamic> libraryEntryJson,
    String? stagedAvatarPath,
    String? stagedCoverPath,
    required bool replaceExisting,
    required DateTime? packAddedAt,
    required DateTime? packLastPlayedAt,
    String? packTitleHint,
  }) async {
    await paths.ensureDirs();

    final stagedRom = File(stagedRomPath);
    if (!await stagedRom.exists()) {
      throw StateError('Staged ROM not found');
    }
    final ext = p.extension(stagedRomPath).toLowerCase();
    if (ext != '.gba' && ext != '.bin') {
      throw StateError('ROM must be .gba or .bin');
    }

    final hash = (await RomIdentity.fromFile(stagedRom)).value;
    if (hash != gameId) {
      throw StateError('ROM hash does not match game id');
    }

    final existing = byId(gameId);
    if (replaceExisting && existing == null) {
      throw StateError('replaceExisting but game missing');
    }
    if (!replaceExisting && existing != null) {
      throw StateError('createNew but game already exists');
    }

    final displayFromMeta =
        (libraryEntryJson['displayName'] as String?)?.trim();
    final titleHint = packTitleHint?.trim();
    final displayName = (displayFromMeta != null && displayFromMeta.isNotEmpty)
        ? displayFromMeta
        : (titleHint != null && titleHint.isNotEmpty)
            ? titleHint
            : (existing?.displayName ?? 'Game');

    final shortId = gameId.length >= 8 ? gameId.substring(0, 8) : gameId;
    final stem = GameLibraryBase._safeFileStem(displayName);
    final romFileName = '${shortId}_$stem$ext';
    final destRom = File(paths.romPathForFileName(romFileName));

    await destRom.parent.create(recursive: true);
    await stagedRom.copy(destRom.path);

    if (existing != null &&
        existing.romFileName.isNotEmpty &&
        existing.romFileName != romFileName) {
      final oldRom = File(paths.romPathForFileName(existing.romFileName));
      if (oldRom.path != destRom.path) {
        await GameLibraryBase._deleteFileQuietly(oldRom);
      }
    }

    var skippedAvatar = false;
    var skippedCover = false;
    String? avatarFileName = existing?.avatarFileName;
    String? coverFileName = existing?.coverFileName;

    if (stagedAvatarPath != null) {
      final allowNew = pro.isPro ||
          existing?.avatarFileName != null ||
          avatarCount < FreeLimits.maxAvatars;
      if (!allowNew) {
        skippedAvatar = true;
      } else {
        final aext = p.extension(stagedAvatarPath).toLowerCase();
        final useExt = GameLibraryArt.imageExts.contains(aext) ? aext : '.png';
        final fileName = paths.avatarFileNameFor(gameId, useExt);
        final dest = File(paths.coverPathForFileName(fileName));
        await File(stagedAvatarPath).copy(dest.path);
        await _writeThumbsForOriginal(fileName);
        final old = avatarFileName;
        avatarFileName = fileName;
        if (old != null && old != fileName) {
          await _deleteArtFile(old);
          _invalidateArtPaintCache(old);
        }
      }
    }

    if (stagedCoverPath != null) {
      final allowNew = pro.isPro ||
          existing?.coverFileName != null ||
          coverCount < FreeLimits.maxCovers;
      if (!allowNew) {
        skippedCover = true;
      } else {
        final cext = p.extension(stagedCoverPath).toLowerCase();
        final useExt = GameLibraryArt.imageExts.contains(cext) ? cext : '.png';
        final fileName = paths.coverBannerFileNameFor(gameId, useExt);
        final dest = File(paths.coverPathForFileName(fileName));
        await File(stagedCoverPath).copy(dest.path);
        await _writeThumbsForOriginal(fileName);
        final old = coverFileName;
        coverFileName = fileName;
        if (old != null && old != fileName) {
          await _deleteArtFile(old);
          _invalidateArtPaintCache(old);
        }
      }
    }

    final description = libraryEntryJson['description'] as String?;
    final headerTitle = libraryEntryJson['headerTitle'] as String?;
    final packPlayTime =
        LibraryGame.parsePlayTimeSeconds(libraryEntryJson['playTimeSeconds']);

    late final LibraryGame applied;

    if (existing == null) {
      final added = packAddedAt ?? DateTime.now();
      applied = LibraryGame(
        id: gameId,
        displayName: displayName,
        romFileName: romFileName,
        addedAt: added,
        lastPlayedAt: DateTime.now(),
        playTimeSeconds: packPlayTime,
        headerTitle: headerTitle,
        description: description,
        avatarFileName: avatarFileName,
        coverFileName: coverFileName,
        missing: false,
      );
      _games.add(applied);
    } else {
      var next = existing.copyWith(
        displayName: displayName,
        romFileName: romFileName,
        lastPlayedAt: packLastPlayedAt ?? existing.lastPlayedAt,
        playTimeSeconds: libraryEntryJson.containsKey('playTimeSeconds')
            ? packPlayTime
            : existing.playTimeSeconds,
        avatarFileName: avatarFileName,
        coverFileName: coverFileName,
        missing: false,
      );

      if (libraryEntryJson.containsKey('description')) {
        final d = (description ?? '').trim();
        next = d.isEmpty
            ? next.copyWith(clearDescription: true)
            : next.copyWith(description: d);
      }
      if (libraryEntryJson.containsKey('headerTitle')) {
        final h = (headerTitle ?? '').trim();
        next = h.isEmpty
            ? next.copyWith(clearHeaderTitle: true)
            : next.copyWith(headerTitle: h);
      }

      final i = _games.indexWhere((g) => g.id == gameId);
      if (i >= 0) _games[i] = next;
      applied = next;
    }

    if (applied.avatarFileName != null) avatarAbsolutePath(applied);
    if (applied.coverFileName != null) coverAbsolutePath(applied);

    await _persist();
    notifyListeners();
    return (
      game: applied,
      createdNew: existing == null,
      skippedAvatar: skippedAvatar,
      skippedCover: skippedCover,
    );
  }

}
