import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/entitlements/free_limits.dart';
import '../../core/storage/safe_file_stem.dart';
import '../../models/game_group.dart';
import '../../models/library_game.dart';
import '../entitlements/pro_access.dart';
import 'art_thumbnailer.dart';
import 'rom_identity.dart';
import '../storage/save_paths.dart';

part 'game_library_art.dart';
part 'game_library_groups.dart';
part 'game_library_pack.dart';

/// Shared state for [GameLibrary] mixins (avoids recursive `on GameLibrary`).
abstract class GameLibraryBase extends ChangeNotifier {
  GameLibraryBase(this.paths, {required this.pro});

  final SavePaths paths;

  /// Free vs Pro — gates custom art, group caps, and multi backup.
  final ProAccess pro;

  final List<LibraryGame> _games = [];
  final List<GameGroup> _groups = [];
  bool _loaded = false;

  /// Paint-path cache keyed by original art file name (+ role).
  /// Resolved once per name; invalidated when art is written/cleared.
  final Map<String, String?> _artPaintCache = {};

  bool get isLoaded => _loaded;

  LibraryGame? byId(String id) {
    for (final g in _games) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Full shelf order: most recently active first (played or newly added).
  List<LibraryGame> get gamesByRecent {
    final list = List<LibraryGame>.from(_games);
    list.sort(_compareRecent);
    return list;
  }

  static DateTime _activityAt(LibraryGame g) {
    final played = g.lastPlayedAt;
    if (played == null) return g.addedAt;
    return played.isAfter(g.addedAt) ? played : g.addedAt;
  }

  static int _compareRecent(LibraryGame a, LibraryGame b) {
    if (a.missing != b.missing) return a.missing ? 1 : -1;
    final c = _activityAt(b).compareTo(_activityAt(a));
    if (c != 0) return c;
    final byAdd = b.addedAt.compareTo(a.addedAt);
    if (byAdd != 0) return byAdd;
    return a.id.compareTo(b.id);
  }

  Future<void> _persist();

  static Future<void> _deleteFileQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static String _safeFileStem(String name) =>
      safeFileStem(name, maxLength: 48);
}

/// Persistent Switch-style game shelf backed by [SavePaths.libraryIndexFile].
///
/// Implementation is split across library parts (groups / art / pack install)
/// so each file stays under a maintainable size. Public API stays on this type.
class GameLibrary extends GameLibraryBase
    with GameLibraryGroups, GameLibraryArt, GameLibraryPack {
  GameLibrary(super.paths, {required super.pro});

  List<LibraryGame> get games => List.unmodifiable(_games);

  /// Home strip: first [limit] entries of [gamesByRecent].
  List<LibraryGame> homeShelf({int limit = 5}) {
    final all = gamesByRecent;
    if (all.length <= limit) return all;
    return all.sublist(0, limit);
  }

  String romPathOf(LibraryGame game) =>
      paths.romPathForFileName(game.romFileName);

  Future<void> load() async {
    await paths.ensureDirs();
    _games.clear();
    _groups.clear();
    _artPaintCache.clear();

    final file = paths.libraryIndexFile;
    if (await file.exists()) {
      try {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final list = decoded['games'];
          if (list is List) {
            for (final item in list) {
              if (item is Map<String, dynamic>) {
                final g = LibraryGame.fromJson(item);
                if (g.id.isNotEmpty && g.romFileName.isNotEmpty) {
                  _games.add(g);
                }
              } else if (item is Map) {
                final g = LibraryGame.fromJson(Map<String, dynamic>.from(item));
                if (g.id.isNotEmpty && g.romFileName.isNotEmpty) {
                  _games.add(g);
                }
              }
            }
          }
          _loadGroupsFromJson(decoded['groups']);
        }
      } catch (_) {
        // Corrupt index: keep empty catalog; ROMs on disk stay intact.
        try {
          final bak = File('${file.path}.bak');
          await file.copy(bak.path);
        } catch (_) {}
      }
    }

    await _reconcile();
    await _importOrphans();
    final pruned = _pruneGroupMembership();
    if (pruned) {
      await _persist();
    }
    // Priority thumbs before first paint/warm — avoids PathNotFound on *_tile.png.
    await _ensurePriorityArtThumbnails();
    _rebuildArtPaintCache();
    _loaded = true;
    notifyListeners();
    // Remaining titles in the background (chunked yields inside).
    Future<void>.microtask(() => _ensureRemainingArtThumbnails());
  }

  Future<void> _reconcile() async {
    final next = <LibraryGame>[];
    for (final g in _games) {
      final f = File(romPathOf(g));
      final exists = await f.exists();
      next.add(g.copyWith(missing: !exists));
    }
    _games
      ..clear()
      ..addAll(next);
  }

  Future<void> _importOrphans() async {
    if (!await paths.romsDir.exists()) return;
    final knownNames = _games.map((g) => g.romFileName).toSet();
    final knownIds = _games.map((g) => g.id).toSet();

    await for (final entity in paths.romsDir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      final ext = p.extension(name).toLowerCase();
      if (ext != '.gba' && ext != '.bin') continue;
      if (knownNames.contains(name)) continue;

      try {
        final id = (await RomIdentity.fromFile(entity)).value;
        if (knownIds.contains(id)) continue;
        final display = _displayNameFromFileName(name);
        final game = LibraryGame(
          id: id,
          displayName: display,
          romFileName: name,
          addedAt: (await entity.stat()).modified,
        );
        _games.add(game);
        knownIds.add(id);
        knownNames.add(name);
      } catch (_) {
        // Skip unreadable files.
      }
    }

    if (_games.isNotEmpty) {
      await _persist();
    }
  }

  @override
  Future<void> _persist() async {
    final payload = <String, dynamic>{
      'version': 2,
      'games': _games.map((g) => g.toJson()).toList(),
      'groups': _groups.map((g) => g.toJson()).toList(),
    };
    final file = paths.libraryIndexFile;
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

  /// Extensions we accept as GBA ROMs (no leading dot).
  static const romExtensions = {'gba', 'bin'};

  static bool isAllowedRomName(String name) {
    final ext = p.extension(name).toLowerCase();
    if (ext.isEmpty) return false;
    return romExtensions.contains(ext.substring(1));
  }

  static String _displayNameFromFileName(String name) {
    final base = p.basenameWithoutExtension(name);
    // Strip leading shortId_ prefix if we stored as {8hex}_{name}.ext
    final m = RegExp(r'^[0-9a-fA-F]{8}_(.+)$').firstMatch(base);
    if (m != null) return m.group(1)!;
    return base;
  }

  /// Import a ROM from an absolute path (used by shell picker and tests).
  Future<LibraryGame> addFromPath(
    String srcPath, {
    String? originalName,
  }) async {
    await paths.ensureDirs();
    final src = File(srcPath);
    if (!await src.exists()) {
      throw StateError('ROM file not found');
    }

    final name = originalName ?? p.basename(srcPath);
    if (!isAllowedRomName(name)) {
      throw StateError('Unsupported file type. Choose a .gba or .bin ROM.');
    }

    final id = (await RomIdentity.fromFile(src)).value;
    final existing = byId(id);
    final now = DateTime.now();
    if (existing != null) {
      final dest = File(romPathOf(existing));
      if (!await dest.exists()) {
        await src.copy(dest.path);
      }
      final updated = existing.copyWith(missing: false, addedAt: now);
      final i = _games.indexWhere((g) => g.id == id);
      if (i >= 0) _games[i] = updated;
      await _persist();
      notifyListeners();
      return updated;
    }

    final ext = p.extension(name).toLowerCase();
    final shortId = id.length >= 8 ? id.substring(0, 8) : id;
    final stem = GameLibraryBase._safeFileStem(name);
    final romFileName = '${shortId}_$stem$ext';
    final destPath = paths.romPathForFileName(romFileName);
    await src.copy(destPath);

    final game = LibraryGame(
      id: id,
      displayName: p.basenameWithoutExtension(name),
      romFileName: romFileName,
      addedAt: now,
    );
    _games.add(game);
    await _persist();
    notifyListeners();
    return game;
  }

  /// Remove [id] from the shelf and wipe all local data for that title:
  /// avatar/cover, app ROM copy, cartridge `.sav`, and savestates.
  Future<void> remove(String id) async {
    final game = byId(id);
    if (game == null) return;
    _games.removeWhere((g) => g.id == id);
    for (var i = 0; i < _groups.length; i++) {
      final g = _groups[i];
      if (!g.gameIds.contains(id)) continue;
      _groups[i] = g.copyWith(
        gameIds: g.gameIds.where((gid) => gid != id).toList(),
      );
    }
    _invalidateArtPaintCache(game.avatarFileName);
    _invalidateArtPaintCache(game.coverFileName);
    await _deleteArtFile(game.avatarFileName);
    await _deleteArtFile(game.coverFileName);
    await GameLibraryBase._deleteFileQuietly(File(romPathOf(game)));
    await paths.deletePlayDataForGame(id);
    await _persist();
    notifyListeners();
  }

  Future<void> touchLastPlayed(String id, {DateTime? at}) async {
    final i = _games.indexWhere((g) => g.id == id);
    if (i < 0) return;
    _games[i] = _games[i].copyWith(lastPlayedAt: at ?? DateTime.now());
    await _persist();
    notifyListeners();
  }

  /// Add [duration] of active play to the title’s cumulative total.
  ///
  /// Rounds to the nearest second so short segments near 0.5s+ still count,
  /// instead of always flooring via [Duration.inSeconds] (which drops under 1s).
  Future<void> addPlayTime(String id, Duration duration) async {
    final addSec = (duration.inMilliseconds / 1000).round();
    if (addSec <= 0) return;
    final i = _games.indexWhere((g) => g.id == id);
    if (i < 0) return;
    final next = _games[i].playTimeSeconds + addSec;
    _games[i] = _games[i].copyWith(playTimeSeconds: next);
    await _persist();
    notifyListeners();
  }

  Future<void> updateHeaderTitle(String id, String title) async {
    final t = title.trim();
    if (t.isEmpty) return;
    final i = _games.indexWhere((g) => g.id == id);
    if (i < 0) return;
    if (_games[i].headerTitle == t) return;
    _games[i] = _games[i].copyWith(headerTitle: t);
    await _persist();
    notifyListeners();
  }

  /// Update user-facing name + description (display settings).
  Future<void> updateDisplayInfo(
    String id, {
    String? displayName,
    String? description,
  }) async {
    final i = _games.indexWhere((g) => g.id == id);
    if (i < 0) return;
    var g = _games[i];
    if (displayName != null) {
      final t = displayName.trim();
      if (t.isNotEmpty) g = g.copyWith(displayName: t);
    }
    if (description != null) {
      final d = description.trim();
      g = d.isEmpty
          ? g.copyWith(clearDescription: true)
          : g.copyWith(description: d);
    }
    _games[i] = g;
    await _persist();
    notifyListeners();
  }
}
