/// One entry in the home game shelf (Switch-style library).
///
/// [id] is the ROM content SHA-256 ([RomIdentity]) — stable across renames and
/// keys cartridge saves / savestates.
class LibraryGame {
  const LibraryGame({
    required this.id,
    required this.displayName,
    required this.romFileName,
    required this.addedAt,
    this.lastPlayedAt,
    this.playTimeSeconds = 0,
    this.headerTitle,
    this.description,
    this.avatarFileName,
    this.coverFileName,
    this.missing = false,
  });

  final String id;
  final String displayName;
  final String romFileName;
  final DateTime addedAt;
  final DateTime? lastPlayedAt;

  /// Cumulative active play time for this title (excludes pause / background).
  final int playTimeSeconds;

  /// Internal GBA header title after first successful load (optional).
  final String? headerTitle;

  /// User-written blurb (display settings / future detail views).
  final String? description;

  /// Original avatar under [SavePaths.coversDir] (any image ext).
  /// UI tiles paint the derived `*_tile.png` via [GameLibrary.avatarAbsolutePath].
  final String? avatarFileName;

  /// Original cover banner under [SavePaths.coversDir].
  /// Backdrop paints derived `*_bg.png` via [GameLibrary.backdropAbsolutePath].
  final String? coverFileName;

  /// True when the ROM file is missing on disk (reconcile).
  final bool missing;

  /// Compact label for badges: `12m`, `1h 05m`, `3h`.
  String get playTimeLabel => formatPlayTimeSeconds(playTimeSeconds);

  /// Human-readable duration for [playTimeSeconds] (and similar counters).
  static String formatPlayTimeSeconds(int totalSeconds) {
    final sec = totalSeconds < 0 ? 0 : totalSeconds;
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) {
      if (m == 0) return '${h}h';
      final mm = m.toString().padLeft(2, '0');
      return '${h}h ${mm}m';
    }
    if (m == 0 && sec > 0) return '<1m';
    return '${m}m';
  }

  /// Coerce JSON / pack values for [playTimeSeconds] (shared by model + pack).
  static int parsePlayTimeSeconds(Object? raw) {
    if (raw is int) return raw < 0 ? 0 : raw;
    if (raw is num) {
      final v = raw.toInt();
      return v < 0 ? 0 : v;
    }
    if (raw is String) {
      final v = int.tryParse(raw.trim());
      if (v != null) return v < 0 ? 0 : v;
    }
    return 0;
  }

  /// Best label for UI tiles (user name first).
  String get title {
    final d = displayName.trim();
    if (d.isNotEmpty) return d;
    final h = headerTitle?.trim();
    if (h != null && h.isNotEmpty) return h;
    return 'Game';
  }

  /// 1–2 letter monogram for placeholder art.
  String get monogram {
    final t = title.trim();
    if (t.isEmpty) return '?';
    final parts = t
        .split(RegExp(r'[\s_\-.]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    if (t.length >= 2) return t.substring(0, 2).toUpperCase();
    return t[0].toUpperCase();
  }

  LibraryGame copyWith({
    String? id,
    String? displayName,
    String? romFileName,
    DateTime? addedAt,
    DateTime? lastPlayedAt,
    int? playTimeSeconds,
    String? headerTitle,
    String? description,
    String? avatarFileName,
    String? coverFileName,
    bool? missing,
    bool clearLastPlayed = false,
    bool clearHeaderTitle = false,
    bool clearDescription = false,
    bool clearAvatar = false,
    bool clearCover = false,
  }) {
    return LibraryGame(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      romFileName: romFileName ?? this.romFileName,
      addedAt: addedAt ?? this.addedAt,
      lastPlayedAt: clearLastPlayed
          ? null
          : (lastPlayedAt ?? this.lastPlayedAt),
      playTimeSeconds: playTimeSeconds ?? this.playTimeSeconds,
      headerTitle: clearHeaderTitle ? null : (headerTitle ?? this.headerTitle),
      description: clearDescription ? null : (description ?? this.description),
      avatarFileName: clearAvatar
          ? null
          : (avatarFileName ?? this.avatarFileName),
      coverFileName: clearCover ? null : (coverFileName ?? this.coverFileName),
      missing: missing ?? this.missing,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'romFileName': romFileName,
    'addedAt': addedAt.toIso8601String(),
    'lastPlayedAt': lastPlayedAt?.toIso8601String(),
    'playTimeSeconds': playTimeSeconds,
    'headerTitle': headerTitle,
    'description': description,
    'avatarFileName': avatarFileName,
    'coverFileName': coverFileName,
  };

  factory LibraryGame.fromJson(Map<String, dynamic> json) {
    DateTime? parseOpt(String? s) {
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return LibraryGame(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Game',
      romFileName: json['romFileName'] as String? ?? '',
      addedAt: parseOpt(json['addedAt'] as String?) ?? DateTime.now(),
      lastPlayedAt: parseOpt(json['lastPlayedAt'] as String?),
      playTimeSeconds: parsePlayTimeSeconds(json['playTimeSeconds']),
      headerTitle: json['headerTitle'] as String?,
      description: json['description'] as String?,
      avatarFileName: json['avatarFileName'] as String?,
      coverFileName: json['coverFileName'] as String?,
    );
  }
}
