/// User-defined folder of library games for quick filtering.
///
/// [gameIds] are [LibraryGame.id] values (ROM content hashes), ordered by
/// when the player added them to the group.
class GameGroup {
  const GameGroup({
    required this.id,
    required this.name,
    required this.createdAt,
    this.gameIds = const [],
  });

  final String id;
  final String name;
  final DateTime createdAt;

  /// Stable ROM ids belonging to this group (order = add order).
  final List<String> gameIds;

  int get gameCount => gameIds.length;

  GameGroup copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<String>? gameIds,
  }) {
    return GameGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      gameIds: gameIds ?? this.gameIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'gameIds': gameIds,
  };

  factory GameGroup.fromJson(Map<String, dynamic> json) {
    DateTime? parseOpt(String? s) {
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    final rawIds = json['gameIds'];
    final ids = <String>[];
    if (rawIds is List) {
      for (final item in rawIds) {
        if (item is String && item.isNotEmpty) {
          ids.add(item);
        }
      }
    }

    return GameGroup(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String? ?? '').trim().isEmpty
          ? 'Group'
          : (json['name'] as String).trim(),
      createdAt: parseOpt(json['createdAt'] as String?) ?? DateTime.now(),
      gameIds: ids,
    );
  }
}
