/// Lemon pack kinds (manifest `kind` field).
enum GamePackKind { saves, full }

/// Prefer share / path-based save when a pack exceeds this size (bytes).
///
/// Shell export delivery uses this constant so it never depends on the
/// concrete zip implementation.
const int kGamePackShareBytesThreshold = 4 * 1024 * 1024;

/// Lightweight inspect result for a single-game `.lemongba.zip` pack.
final class GamePackInfo {
  const GamePackInfo({
    required this.kind,
    required this.gameId,
    required this.exportedAt,
    this.title,
    this.formatVersion = 1,
  });

  final GamePackKind kind;
  final String gameId;
  final DateTime exportedAt;
  final String? title;
  final int formatVersion;
}

/// Temp zip ready for platform export (share / save dialog).
final class GamePackExportResult {
  const GamePackExportResult({
    required this.tempFilePath,
    required this.suggestedFileName,
    required this.byteLength,
    required this.kind,
  });

  final String tempFilePath;
  final String suggestedFileName;
  final int byteLength;
  final GamePackKind kind;
}

/// How a full pack should be applied relative to the library index.
enum GamePackImportMode {
  /// Save pack only — replace play data for [expectedGameId].
  replaceSaves,

  /// Full pack: create a new library row.
  createNew,

  /// Full pack: overwrite an existing library row.
  replaceExisting,
}

/// How group folders were restored from a full pack (multi or single).
final class GroupPackRestoreResult {
  const GroupPackRestoreResult({
    this.created = 0,
    this.membershipUpdated = 0,
    this.existingGroupsUpdated = 0,
    this.skippedCreate = 0,
  });

  /// New group folders created from the pack.
  final int created;

  /// Games added to an existing or newly created group (member link count).
  final int membershipUpdated;

  /// Existing local groups that received at least one new member from the pack.
  final int existingGroupsUpdated;

  /// Pack groups not created because free-tier group cap was hit.
  final int skippedCreate;

  bool get anyChange => created > 0 || membershipUpdated > 0;

  static const empty = GroupPackRestoreResult();
}

final class GamePackImportResult {
  const GamePackImportResult({
    required this.gameId,
    required this.kind,
    required this.createdNew,
    this.skippedAvatar = false,
    this.skippedCover = false,
    this.title,
    this.groups = GroupPackRestoreResult.empty,
  });

  final String gameId;
  final GamePackKind kind;
  final bool createdNew;
  final bool skippedAvatar;
  final bool skippedCover;
  final String? title;

  /// Groups restored from a full pack (empty for save packs / older packs).
  final GroupPackRestoreResult groups;
}

/// One game entry inside a multi Lemon pack (`lemongba.multi.pack`).
///
/// [root] is a relative directory prefix inside the zip (e.g. `games/<id>`),
/// not a nested zip path.
final class MultiGamePackEntry {
  const MultiGamePackEntry({
    required this.gameId,
    required this.root,
    this.title,
  });

  final String gameId;

  /// Relative directory of this game’s tree inside the multi archive.
  final String root;
  final String? title;
}

/// Inspect result for a multi save/full pack (flat multi-root archive).
final class MultiGamePackInfo {
  const MultiGamePackInfo({
    required this.kind,
    required this.exportedAt,
    required this.games,
    this.formatVersion = 1,
  });

  /// Nested game trees are all [GamePackKind.saves] or all [GamePackKind.full].
  final GamePackKind kind;
  final DateTime exportedAt;
  final List<MultiGamePackEntry> games;
  final int formatVersion;

  int get gameCount => games.length;
}

/// Per-game outcome inside a multi import.
enum MultiGamePackEntryStatus { imported, skipped, failed }

final class MultiGamePackEntryResult {
  const MultiGamePackEntryResult({
    required this.gameId,
    required this.status,
    this.title,
    this.errorCode,
    this.errorMessage,
    this.createdNew = false,
    this.skippedAvatar = false,
    this.skippedCover = false,
  });

  final String gameId;
  final String? title;
  final MultiGamePackEntryStatus status;
  final GamePackErrorCode? errorCode;
  final String? errorMessage;
  final bool createdNew;
  final bool skippedAvatar;
  final bool skippedCover;
}

/// Aggregate result after applying a multi pack.
final class MultiGamePackImportResult {
  const MultiGamePackImportResult({
    required this.kind,
    required this.entries,
    this.groups = GroupPackRestoreResult.empty,
  });

  final GamePackKind kind;
  final List<MultiGamePackEntryResult> entries;

  /// Group restore summary (full multi packs only; empty for save packs).
  final GroupPackRestoreResult groups;

  int get imported =>
      entries.where((e) => e.status == MultiGamePackEntryStatus.imported).length;

  int get skipped =>
      entries.where((e) => e.status == MultiGamePackEntryStatus.skipped).length;

  int get failed =>
      entries.where((e) => e.status == MultiGamePackEntryStatus.failed).length;

  bool get anySkippedAvatar =>
      entries.any((e) => e.skippedAvatar);

  bool get anySkippedCover =>
      entries.any((e) => e.skippedCover);

  List<String> get importedTitles => [
        for (final e in entries)
          if (e.status == MultiGamePackEntryStatus.imported &&
              e.title != null &&
              e.title!.isNotEmpty)
            e.title!,
      ];
}

/// Result of [GamePackPort.inspect] — single or multi pack.
sealed class PackInspectResult {
  const PackInspectResult();
}

final class SinglePackInspect extends PackInspectResult {
  const SinglePackInspect(this.info);
  final GamePackInfo info;
}

final class MultiPackInspect extends PackInspectResult {
  const MultiPackInspect(this.info);
  final MultiGamePackInfo info;
}

enum GamePackErrorCode {
  invalidFormat,
  unsupportedVersion,
  wrongKind,
  wrongGame,
  romMissing,
  gameNotInLibrary,
  ioFailure,
  corruptEntry,
  modeMismatch,
  exportTooLarge,
}

/// Thrown by [GamePackPort] implementations.
class GamePackException implements Exception {
  const GamePackException(this.code, [this.message]);

  final GamePackErrorCode code;
  final String? message;

  @override
  String toString() =>
      message == null ? 'GamePackException($code)' : 'GamePackException($code): $message';
}

/// Export / import of Lemon save packs and full game packs.
///
/// Shell orchestrates pickers and confirms; implementations own zip I/O and
/// play-data paths.
///
/// **Multi packs** are a single flat zip (`lemongba.multi.pack`) with one
/// directory tree per game (`games/<gameId>/…`), not nested zip files.
abstract interface class GamePackPort {
  Future<GamePackExportResult> exportSavePack({
    required String gameId,
    required String titleForFileName,
  });

  Future<GamePackExportResult> exportFullPack({
    required String gameId,
    required String titleForFileName,
  });

  /// Bundle several games into one multi archive
  /// (`*.saves.multi.lemongba.zip` or `*.full.multi.lemongba.zip`).
  /// [gameIds] must be non-empty library ids.
  Future<GamePackExportResult> exportMultiPack({
    required GamePackKind kind,
    required List<String> gameIds,
  });

  /// Inspect a single or multi Lemon pack (sealed result).
  Future<PackInspectResult> inspect(String zipPath);

  /// [expectedGameId] must equal manifest.gameId (save packs only).
  Future<GamePackImportResult> importSavePack({
    required String zipPath,
    required String expectedGameId,
  });

  /// Shell chooses [mode] from inspect + library; service hard-rejects
  /// mismatches (createNew when id exists, replaceExisting when missing).
  Future<GamePackImportResult> importFullPack({
    required String zipPath,
    required GamePackImportMode mode,
  });

  /// Restore a multi pack. Kind and create/skip/replace policy come from the
  /// manifest + current library. Per-game outcomes are in
  /// [MultiGamePackImportResult.entries].
  Future<MultiGamePackImportResult> importMultiPack(String zipPath);
}
