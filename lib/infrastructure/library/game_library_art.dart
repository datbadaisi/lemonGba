part of 'game_library.dart';

/// Art paths, thumbnails, free-tier art caps. Mixed into [GameLibrary].
mixin GameLibraryArt on GameLibraryBase {
  /// Games currently using a custom tile image.
  int get avatarCount =>
      _games.where((g) => g.avatarFileName != null).length;

  /// Games currently using a custom cover / backdrop image.
  int get coverCount =>
      _games.where((g) => g.coverFileName != null).length;

  bool canSetAvatar(String gameId) {
    if (pro.isPro) return true;
    final g = byId(gameId);
    if (g?.avatarFileName != null) return true;
    return avatarCount < FreeLimits.maxAvatars;
  }

  bool canSetCover(String gameId) {
    if (pro.isPro) return true;
    final g = byId(gameId);
    if (g?.coverFileName != null) return true;
    return coverCount < FreeLimits.maxCovers;
  }

  static const int _thumbPriorityCount = 24;

  /// Original imported avatar (full resolution). Prefer [avatarAbsolutePath].
  String? avatarOriginalPath(LibraryGame game) {
    final name = game.avatarFileName;
    if (name == null || name.isEmpty) return null;
    return paths.coverPathForFileName(name);
  }

  /// Best paint path for a tile: `*_tile.png` → original → null.
  ///
  /// Uses the session paint cache — **no** `existsSync` on the hot build path
  /// after the first resolve / load-time rebuild.
  String? avatarAbsolutePath(LibraryGame game) {
    final name = game.avatarFileName;
    if (name == null || name.isEmpty) return null;
    return _cachedArtPath(
      name,
      role: 'tile',
      tile: paths.tileThumbPathForOriginal(name),
      original: paths.coverPathForFileName(name),
    );
  }

  /// Cover slot preview: tile thumb if ready, else original.
  String? coverAbsolutePath(LibraryGame game) {
    final name = game.coverFileName;
    if (name == null || name.isEmpty) return null;
    return _cachedArtPath(
      name,
      role: 'tile',
      tile: paths.tileThumbPathForOriginal(name),
      original: paths.coverPathForFileName(name),
    );
  }

  /// Home blur: `*_bg.png` → tile → original (cover preferred over avatar).
  String? backdropAbsolutePath(LibraryGame game) {
    final cover = game.coverFileName;
    if (cover != null && cover.isNotEmpty) {
      final p = _cachedArtPath(
        cover,
        role: 'bg',
        backdrop: paths.backdropThumbPathForOriginal(cover),
        tile: paths.tileThumbPathForOriginal(cover),
        original: paths.coverPathForFileName(cover),
      );
      if (p != null) return p;
    }
    final avatar = game.avatarFileName;
    if (avatar != null && avatar.isNotEmpty) {
      return _cachedArtPath(
        avatar,
        role: 'bg',
        backdrop: paths.backdropThumbPathForOriginal(avatar),
        tile: paths.tileThumbPathForOriginal(avatar),
        original: paths.coverPathForFileName(avatar),
      );
    }
    return null;
  }

  String _artCacheKey(String fileName, String role) => '$role|$fileName';

  String? _cachedArtPath(
    String fileName, {
    required String role,
    String? backdrop,
    String? tile,
    String? original,
  }) {
    final key = _artCacheKey(fileName, role);
    if (_artPaintCache.containsKey(key)) {
      return _artPaintCache[key];
    }
    final resolved = _existingArtPath(
      backdrop: backdrop,
      tile: tile,
      original: original,
    );
    _artPaintCache[key] = resolved;
    return resolved;
  }

  /// Resolve once when filling the cache (load / art write / thumb migration).
  String? _existingArtPath({
    String? backdrop,
    String? tile,
    String? original,
  }) {
    if (backdrop != null && backdrop.isNotEmpty && File(backdrop).existsSync()) {
      return backdrop;
    }
    if (tile != null && tile.isNotEmpty && File(tile).existsSync()) {
      return tile;
    }
    if (original != null &&
        original.isNotEmpty &&
        File(original).existsSync()) {
      return original;
    }
    return null;
  }

  void _invalidateArtPaintCache(String? fileName) {
    if (fileName == null || fileName.isEmpty) return;
    _artPaintCache.remove(_artCacheKey(fileName, 'tile'));
    _artPaintCache.remove(_artCacheKey(fileName, 'bg'));
  }

  void _rebuildArtPaintCache() {
    _artPaintCache.clear();
    for (final g in _games) {
      if (g.avatarFileName != null) {
        avatarAbsolutePath(g);
        final name = g.avatarFileName!;
        _cachedArtPath(
          name,
          role: 'bg',
          backdrop: paths.backdropThumbPathForOriginal(name),
          tile: paths.tileThumbPathForOriginal(name),
          original: paths.coverPathForFileName(name),
        );
      }
      if (g.coverFileName != null) {
        coverAbsolutePath(g);
        final name = g.coverFileName!;
        _cachedArtPath(
          name,
          role: 'bg',
          backdrop: paths.backdropThumbPathForOriginal(name),
          tile: paths.tileThumbPathForOriginal(name),
          original: paths.coverPathForFileName(name),
        );
      }
    }
  }

  Future<void> ensureArtThumbnails() async {
    await _ensurePriorityArtThumbnails();
    await _ensureRemainingArtThumbnails();
  }

  Future<void> _ensurePriorityArtThumbnails() async {
    if (_games.isEmpty) return;
    var dirty = false;
    for (final g in gamesByRecent.take(_thumbPriorityCount)) {
      if (await _ensureThumbsForGame(g)) dirty = true;
    }
    if (dirty) {
      _rebuildArtPaintCache();
      if (_loaded) notifyListeners();
    }
  }

  Future<void> _ensureRemainingArtThumbnails() async {
    if (_games.isEmpty) return;
    var dirty = false;
    for (final g in gamesByRecent.skip(_thumbPriorityCount)) {
      if (await _ensureThumbsForGame(g)) dirty = true;
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
    if (dirty) {
      _rebuildArtPaintCache();
      if (_loaded) notifyListeners();
    }
  }

  Future<bool> _ensureThumbsForGame(LibraryGame game) async {
    final a = await _ensureThumbsForOriginal(game.avatarFileName);
    final c = await _ensureThumbsForOriginal(game.coverFileName);
    return a || c;
  }

  Future<bool> _ensureThumbsForOriginal(String? originalFileName) async {
    if (originalFileName == null || originalFileName.isEmpty) return false;
    final src = File(paths.coverPathForFileName(originalFileName));
    if (!await src.exists()) return false;

    var wrote = false;
    final tile = File(paths.tileThumbPathForOriginal(originalFileName));
    if (await ArtThumbnailer.needsRewrite(
      source: src,
      thumb: tile,
      maxEdge: ArtThumbnailer.tileMaxEdge,
    )) {
      wrote =
          await ArtThumbnailer.writeTileThumb(source: src, dest: tile) || wrote;
    }
    final bg = File(paths.backdropThumbPathForOriginal(originalFileName));
    if (await ArtThumbnailer.needsRewrite(
      source: src,
      thumb: bg,
      maxEdge: ArtThumbnailer.backdropMaxEdge,
    )) {
      wrote = await ArtThumbnailer.writeBackdropThumb(source: src, dest: bg) ||
          wrote;
    }
    if (wrote) _invalidateArtPaintCache(originalFileName);
    return wrote;
  }

  Future<void> _writeThumbsForOriginal(String originalFileName) async {
    final src = File(paths.coverPathForFileName(originalFileName));
    if (!await src.exists()) return;
    await ArtThumbnailer.writeTileThumb(
      source: src,
      dest: File(paths.tileThumbPathForOriginal(originalFileName)),
    );
    await ArtThumbnailer.writeBackdropThumb(
      source: src,
      dest: File(paths.backdropThumbPathForOriginal(originalFileName)),
    );
    _invalidateArtPaintCache(originalFileName);
  }

  static const imageExts = {'.png', '.jpg', '.jpeg', '.webp', '.gif'};

  Future<void> setAvatarFromPath(String id, String srcPath) async {
    await _setArt(id, srcPath, isAvatar: true);
  }

  Future<void> setCoverFromPath(String id, String srcPath) async {
    await _setArt(id, srcPath, isAvatar: false);
  }

  Future<void> clearAvatar(String id) async {
    final i = _games.indexWhere((g) => g.id == id);
    if (i < 0) return;
    final g = _games[i];
    final old = g.avatarFileName;
    await _deleteArtFile(old);
    _invalidateArtPaintCache(old);
    _games[i] = g.copyWith(clearAvatar: true);
    await _persist();
    notifyListeners();
  }

  Future<void> clearCover(String id) async {
    final i = _games.indexWhere((g) => g.id == id);
    if (i < 0) return;
    final g = _games[i];
    final old = g.coverFileName;
    await _deleteArtFile(old);
    _invalidateArtPaintCache(old);
    _games[i] = g.copyWith(clearCover: true);
    await _persist();
    notifyListeners();
  }

  Future<void> _setArt(
    String id,
    String srcPath, {
    required bool isAvatar,
  }) async {
    final i = _games.indexWhere((g) => g.id == id);
    if (i < 0) return;

    if (isAvatar) {
      if (!canSetAvatar(id)) {
        throw FreeTierLimitException(FreeTierMessages.avatars);
      }
    } else {
      if (!canSetCover(id)) {
        throw FreeTierLimitException(FreeTierMessages.covers);
      }
    }

    await paths.ensureDirs();

    final src = File(srcPath);
    if (!await src.exists()) {
      throw StateError('Image file not found');
    }
    var ext = p.extension(srcPath).toLowerCase();
    if (!imageExts.contains(ext)) ext = '.png';

    final g = _games[i];
    final fileName = isAvatar
        ? paths.avatarFileNameFor(id, ext)
        : paths.coverBannerFileNameFor(id, ext);
    final dest = File(paths.coverPathForFileName(fileName));
    final oldName = isAvatar ? g.avatarFileName : g.coverFileName;

    await src.copy(dest.path);
    await _writeThumbsForOriginal(fileName);
    _games[i] = isAvatar
        ? g.copyWith(avatarFileName: fileName)
        : g.copyWith(coverFileName: fileName);
    _invalidateArtPaintCache(fileName);
    if (isAvatar) {
      avatarAbsolutePath(_games[i]);
    } else {
      coverAbsolutePath(_games[i]);
    }
    await _persist();
    notifyListeners();

    if (oldName != null && oldName != fileName) {
      await _deleteArtFile(oldName);
      _invalidateArtPaintCache(oldName);
    }
  }

  List<String> artPathsForFileName(String? fileName) {
    if (fileName == null || fileName.isEmpty) return const [];
    return [
      paths.coverPathForFileName(fileName),
      paths.tileThumbPathForOriginal(fileName),
      paths.backdropThumbPathForOriginal(fileName),
    ];
  }

  Future<void> _deleteArtFile(String? fileName) async {
    if (fileName == null || fileName.isEmpty) return;
    await GameLibraryBase._deleteFileQuietly(
      File(paths.coverPathForFileName(fileName)),
    );
    await GameLibraryBase._deleteFileQuietly(
      File(paths.tileThumbPathForOriginal(fileName)),
    );
    await GameLibraryBase._deleteFileQuietly(
      File(paths.backdropThumbPathForOriginal(fileName)),
    );
  }
}
