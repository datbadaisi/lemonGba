import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../library/rom_identity.dart';

/// One play-data file candidate for packaging (may or may not exist on disk).
final class PlayDataMember {
  const PlayDataMember({
    required this.absolutePath,
    required this.zipPath,
    required this.role,
    this.slot,
  });

  final String absolutePath;
  final String zipPath;
  final String role;
  final int? slot;
}

/// App-scoped paths for ROMs, cartridge saves, and savestates.
class SavePaths {
  SavePaths._(this.root);

  final Directory root;

  /// Test / packaging constructor — does not touch path_provider.
  factory SavePaths.forRoot(Directory root) => SavePaths._(root);

  static Future<SavePaths> open() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory(p.join(base.path, 'gba'));
    await root.create(recursive: true);
    return SavePaths._(root);
  }

  Directory get romsDir => Directory(p.join(root.path, 'roms'));
  Directory get savesDir => Directory(p.join(root.path, 'saves'));
  Directory get statesDir => Directory(p.join(root.path, 'states'));
  Directory get coversDir => Directory(p.join(root.path, 'covers'));

  /// Persistent home library catalog (JSON).
  File get libraryIndexFile => File(p.join(root.path, 'library.json'));

  /// User-customized play control layout (JSON).
  File get playLayoutFile => File(p.join(root.path, 'play_layout.json'));

  Future<void> ensureDirs() async {
    await romsDir.create(recursive: true);
    await savesDir.create(recursive: true);
    await statesDir.create(recursive: true);
    await coversDir.create(recursive: true);
  }

  String romPathForFileName(String romFileName) {
    return p.join(romsDir.path, romFileName);
  }

  String coverPathForFileName(String fileName) {
    return p.join(coversDir.path, fileName);
  }

  /// Default on-disk names for user art (extension supplied by import).
  ///
  /// Each import gets a unique [stamp] so replacing art changes the path.
  /// Stable paths (`id_avatar.jpg`) would keep Flutter [ImageCache] / warm
  /// keys on the old decode after the file is overwritten.
  String avatarFileNameFor(String gameId, String ext, {int? stamp}) {
    final id = gameId.length >= 16 ? gameId.substring(0, 16) : gameId;
    final s = stamp ?? DateTime.now().microsecondsSinceEpoch;
    return '${id}_avatar_$s$ext';
  }

  String coverBannerFileNameFor(String gameId, String ext, {int? stamp}) {
    final id = gameId.length >= 16 ? gameId.substring(0, 16) : gameId;
    final s = stamp ?? DateTime.now().microsecondsSinceEpoch;
    return '${id}_cover_$s$ext';
  }

  /// Tile thumbnail next to an original (`foo_avatar.jpg` → `foo_avatar_tile.png`).
  String tileThumbFileName(String originalFileName) {
    final base = p.basenameWithoutExtension(originalFileName);
    return '${base}_tile.png';
  }

  /// Backdrop thumbnail (`foo_cover.jpg` → `foo_cover_bg.png`).
  String backdropThumbFileName(String originalFileName) {
    final base = p.basenameWithoutExtension(originalFileName);
    return '${base}_bg.png';
  }

  String tileThumbPathForOriginal(String originalFileName) =>
      coverPathForFileName(tileThumbFileName(originalFileName));

  String backdropThumbPathForOriginal(String originalFileName) =>
      coverPathForFileName(backdropThumbFileName(originalFileName));

  Future<String> gameIdForRom(String romPath) async {
    return (await RomIdentity.fromFile(File(romPath))).value;
  }

  String savPathForGame(String gameId) {
    return p.join(savesDir.path, '$gameId.sav');
  }

  /// Absolute path of the per-game savestate folder (`states/<gameId>/`).
  String stateDirForGame(String gameId) => _gameStateDir(gameId);

  /// Absolute path of quick-rotate meta for [gameId].
  String quickRotateMetaPathForGame(String gameId) =>
      _quickRotateMetaPath(gameId);

  /// Staging / export root under app storage (`tmp/packs/`).
  Directory get packsTempDir => Directory(p.join(root.path, 'tmp', 'packs'));

  /// Inventory of cartridge + all slots + rotate meta (paths only; may not exist).
  List<PlayDataMember> playDataMembersForGame(String gameId) {
    final out = <PlayDataMember>[
      PlayDataMember(
        absolutePath: savPathForGame(gameId),
        zipPath: 'saves/cartridge.sav',
        role: 'cartridge',
      ),
    ];
    for (var i = 1; i <= quickSaveSlotCount; i++) {
      out.add(
        PlayDataMember(
          absolutePath: quickStatePathForGame(gameId, i),
          zipPath: 'states/quick$i.state',
          role: 'quick',
          slot: i,
        ),
      );
    }
    for (var i = 1; i <= manualSlotCount; i++) {
      out.add(
        PlayDataMember(
          absolutePath: statePathForGame(gameId, i),
          zipPath: 'states/slot$i.state',
          role: 'manual',
          slot: i,
        ),
      );
    }
    out.add(
      PlayDataMember(
        absolutePath: quickRotateMetaPathForGame(gameId),
        zipPath: 'states/quick_rotate.json',
        role: 'quick_rotate',
      ),
    );
    return out;
  }

  /// Wipe cartridge save + savestate tree for [gameId].
  ///
  /// Used when the user removes a title and wants a clean slate on re-import
  /// (same ROM content hash → same [gameId]).
  Future<void> deletePlayDataForGame(String gameId) async {
    await _deleteFileQuietly(File(savPathForGame(gameId)));
    await _deleteDirQuietly(Directory(_gameStateDir(gameId)));
  }

  static Future<void> _deleteFileQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<void> _deleteDirQuietly(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// Circular auto quick-save slots written on Save & Exit (1…[quickSaveSlotCount]).
  static const int quickSaveSlotCount = 10;

  /// Numbered manual slots under Save / Load States.
  static const int manualSlotCount = 5;

  String _gameStateDir(String gameId) => p.join(statesDir.path, gameId);

  /// Manual savestate path (`slot1.state` … `slotN.state`).
  String statePathForGame(String gameId, int slot) {
    return p.join(_gameStateDir(gameId), 'slot$slot.state');
  }

  /// Circular quick-save path (`quick1.state` … `quickN.state`).
  String quickStatePathForGame(String gameId, int slot) {
    return p.join(_gameStateDir(gameId), 'quick$slot.state');
  }

  /// Pre-rotation single quick file; migrated into slot 1 when present.
  String legacyQuickStatePathForGame(String gameId) {
    return p.join(_gameStateDir(gameId), 'quick.state');
  }

  String _quickRotateMetaPath(String gameId) {
    return p.join(_gameStateDir(gameId), 'quick_rotate.json');
  }

  Future<void> ensureStateDir(String gameId) async {
    await Directory(_gameStateDir(gameId)).create(recursive: true);
  }

  Future<Map<String, dynamic>> _readQuickRotateMeta(String gameId) async {
    final file = File(_quickRotateMetaPath(gameId));
    if (!await file.exists()) return const {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return const {};
  }

  Future<void> _writeQuickRotateMeta(
    String gameId,
    Map<String, dynamic> meta,
  ) async {
    await ensureStateDir(gameId);
    final file = File(_quickRotateMetaPath(gameId));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(meta));
  }

  /// Next circular slot (1…[quickSaveSlotCount]) for the upcoming exit save.
  Future<int> nextQuickSaveSlot(String gameId) async {
    final meta = await _readQuickRotateMeta(gameId);
    final next = meta['nextSlot'];
    if (next is int && next >= 1 && next <= quickSaveSlotCount) return next;
    if (next is num) {
      final n = next.toInt();
      if (n >= 1 && n <= quickSaveSlotCount) return n;
    }
    return 1;
  }

  /// Most recently written circular slot, or null if none yet.
  Future<int?> lastQuickSaveSlot(String gameId) async {
    final meta = await _readQuickRotateMeta(gameId);
    final last = meta['lastSlot'];
    if (last is int && last >= 1 && last <= quickSaveSlotCount) return last;
    if (last is num) {
      final n = last.toInt();
      if (n >= 1 && n <= quickSaveSlotCount) return n;
    }
    return null;
  }

  /// After a successful exit quick-save: record [writtenSlot] and advance ring.
  Future<void> advanceQuickSaveRotation(String gameId, int writtenSlot) async {
    final slot = writtenSlot.clamp(1, quickSaveSlotCount);
    final next = slot >= quickSaveSlotCount ? 1 : slot + 1;
    await _writeQuickRotateMeta(gameId, {'nextSlot': next, 'lastSlot': slot});
  }

  /// One-time: old single `quick.state` → `quick1.state` if ring is empty.
  Future<void> migrateLegacyQuickSaveIfNeeded(String gameId) async {
    final legacy = File(legacyQuickStatePathForGame(gameId));
    if (!await legacy.exists()) return;

    final first = File(quickStatePathForGame(gameId, 1));
    if (await first.exists()) {
      // Ring already in use — drop the orphan quietly.
      try {
        await legacy.delete();
      } catch (_) {}
      return;
    }

    await ensureStateDir(gameId);
    try {
      await legacy.rename(first.path);
    } catch (_) {
      try {
        await legacy.copy(first.path);
        await legacy.delete();
      } catch (_) {
        return;
      }
    }

    final last = await lastQuickSaveSlot(gameId);
    if (last == null) {
      await _writeQuickRotateMeta(gameId, {'nextSlot': 2, 'lastSlot': 1});
    }
  }
}
