part of 'game_library.dart';

/// Group folders + membership. Mixed into [GameLibrary].
mixin GameLibraryGroups on GameLibraryBase {
  /// User folders for quick filtering — always A→Z by name (case-insensitive).
  List<GameGroup> get groups {
    final list = List<GameGroup>.from(_groups);
    list.sort(_compareGroupName);
    return List.unmodifiable(list);
  }

  GameGroup? groupById(String id) {
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  static int _compareGroupName(GameGroup a, GameGroup b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (byName != 0) return byName;
    return a.id.compareTo(b.id);
  }

  void _loadGroupsFromJson(Object? raw) {
    if (raw is! List) return;
    final seen = <String>{};
    for (final item in raw) {
      Map<String, dynamic>? map;
      if (item is Map<String, dynamic>) {
        map = item;
      } else if (item is Map) {
        map = Map<String, dynamic>.from(item);
      }
      if (map == null) continue;
      final g = GameGroup.fromJson(map);
      if (g.id.isEmpty || seen.contains(g.id)) continue;
      seen.add(g.id);
      _groups.add(g);
    }
  }

  bool _pruneGroupMembership() {
    final known = _games.map((g) => g.id).toSet();
    var changed = false;
    for (var i = 0; i < _groups.length; i++) {
      final g = _groups[i];
      final kept = g.gameIds.where(known.contains).toList();
      if (kept.length != g.gameIds.length) {
        _groups[i] = g.copyWith(gameIds: kept);
        changed = true;
      }
    }
    return changed;
  }

  /// Prefer [preferred] when non-empty and unused; otherwise mint a unique id.
  String _allocateGroupId({String? preferred}) {
    final want = preferred?.trim() ?? '';
    if (want.isNotEmpty && !_groups.any((g) => g.id == want)) {
      return want;
    }
    for (var n = 0; n < 64; n++) {
      final ms = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
      final id = n == 0 ? 'grp_$ms' : 'grp_${ms}_$n';
      if (!_groups.any((g) => g.id == id)) return id;
    }
    // Extremely unlikely collision storm — fall back to length suffix.
    return 'grp_${DateTime.now().microsecondsSinceEpoch}_${_groups.length}';
  }

  List<LibraryGame> gamesInGroup(String groupId) {
    final group = groupById(groupId);
    if (group == null) return const [];
    final out = <LibraryGame>[];
    for (final id in group.gameIds) {
      final g = byId(id);
      if (g != null) out.add(g);
    }
    return out;
  }

  bool isGameInGroup(String groupId, String gameId) {
    final group = groupById(groupId);
    if (group == null) return false;
    return group.gameIds.contains(gameId);
  }

  List<GameGroup> groupsForGame(String gameId) {
    final list = _groups.where((g) => g.gameIds.contains(gameId)).toList();
    list.sort(_compareGroupName);
    return list;
  }

  bool canCreateGroup() {
    if (pro.isPro) return true;
    return _groups.length < FreeLimits.maxGroups;
  }

  Future<GameGroup> createGroup(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw StateError('Group name cannot be empty');
    }
    if (!canCreateGroup()) {
      throw FreeTierLimitException(FreeTierMessages.groups);
    }
    final group = GameGroup(
      id: _allocateGroupId(),
      name: trimmed,
      createdAt: DateTime.now(),
    );
    _groups.add(group);
    await _persist();
    notifyListeners();
    return group;
  }

  Future<void> renameGroup(String groupId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw StateError('Group name cannot be empty');
    }
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i < 0) return;
    if (_groups[i].name == trimmed) return;
    _groups[i] = _groups[i].copyWith(name: trimmed);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteGroup(String groupId) async {
    final before = _groups.length;
    _groups.removeWhere((g) => g.id == groupId);
    if (_groups.length == before) return;
    await _persist();
    notifyListeners();
  }

  Future<void> addGameToGroup(String groupId, String gameId) async {
    if (byId(gameId) == null) return;
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i < 0) return;
    final g = _groups[i];
    if (g.gameIds.contains(gameId)) return;
    _groups[i] = g.copyWith(gameIds: [...g.gameIds, gameId]);
    await _persist();
    notifyListeners();
  }

  Future<void> removeGameFromGroup(String groupId, String gameId) async {
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i < 0) return;
    final g = _groups[i];
    if (!g.gameIds.contains(gameId)) return;
    _groups[i] = g.copyWith(
      gameIds: g.gameIds.where((id) => id != gameId).toList(),
    );
    await _persist();
    notifyListeners();
  }

  /// Replace membership of [groupId] with [gameIds].
  ///
  /// Existing ids that remain keep relative order; new ids append in
  /// [gameIds] order. Unknown / duplicate ids are dropped.
  Future<void> setGroupGames(String groupId, List<String> gameIds) async {
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i < 0) return;
    final known = _games.map((g) => g.id).toSet();
    final selected = <String>{
      for (final id in gameIds)
        if (known.contains(id)) id,
    };
    final prev = _groups[i].gameIds;
    final next = <String>[
      ...prev.where(selected.contains),
      ...gameIds.where((id) => selected.contains(id) && !prev.contains(id)),
    ];
    final seen = <String>{};
    final deduped = <String>[];
    for (final id in next) {
      if (seen.add(id)) deduped.add(id);
    }
    if (_listEquals(deduped, prev)) return;
    _groups[i] = _groups[i].copyWith(gameIds: deduped);
    await _persist();
    notifyListeners();
  }

  /// Atomically set which groups contain [gameId] (one persist / notify).
  Future<void> setGroupsForGame(String gameId, Set<String> groupIds) async {
    if (byId(gameId) == null) return;
    var changed = false;
    for (var i = 0; i < _groups.length; i++) {
      final g = _groups[i];
      final has = g.gameIds.contains(gameId);
      final should = groupIds.contains(g.id);
      if (has == should) continue;
      changed = true;
      if (should) {
        _groups[i] = g.copyWith(gameIds: [...g.gameIds, gameId]);
      } else {
        _groups[i] = g.copyWith(
          gameIds: g.gameIds.where((id) => id != gameId).toList(),
        );
      }
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  Future<bool> toggleGameInGroup(String groupId, String gameId) async {
    if (isGameInGroup(groupId, gameId)) {
      await removeGameFromGroup(groupId, gameId);
      return false;
    }
    await addGameToGroup(groupId, gameId);
    return true;
  }

  /// Merge group folders from a full pack into the local library.
  ///
  /// - Matches existing groups by **id**, then by **name** (case-insensitive).
  /// - Creates missing groups (respects free-tier [FreeLimits.maxGroups]).
  /// - Membership is **additive** (not a full snapshot rewrite): pack game
  ///   ids in [relevantGameIds] are appended; local members not listed in the
  ///   pack stay. A game may remain in local-only groups the pack never
  ///   mentioned. Reinstall-after-wipe still restores pack membership cleanly
  ///   because local groups start empty.
  /// - Groups with no known members after filtering are skipped.
  ///
  /// Used by full-pack import (single + multi). Save packs never call this.
  Future<
      ({
        int created,
        int membershipUpdated,
        int existingGroupsUpdated,
        int skippedCreate,
      })> mergeGroupsFromPack(
    List<Map<String, dynamic>> packGroups, {
    required Set<String> relevantGameIds,
  }) async {
    if (packGroups.isEmpty || relevantGameIds.isEmpty) {
      return (
        created: 0,
        membershipUpdated: 0,
        existingGroupsUpdated: 0,
        skippedCreate: 0,
      );
    }

    var created = 0;
    var membershipUpdated = 0;
    var existingGroupsUpdated = 0;
    var skippedCreate = 0;
    var changed = false;

    for (final raw in packGroups) {
      final pack = GameGroup.fromJson(raw);
      final name = pack.name.trim().isEmpty ? 'Group' : pack.name.trim();
      final members = <String>[];
      final seenMember = <String>{};
      for (final id in pack.gameIds) {
        if (!relevantGameIds.contains(id)) continue;
        if (byId(id) == null) continue;
        if (seenMember.add(id)) members.add(id);
      }
      if (members.isEmpty) continue;

      var index = -1;
      if (pack.id.isNotEmpty) {
        index = _groups.indexWhere((g) => g.id == pack.id);
      }
      if (index < 0) {
        final lower = name.toLowerCase();
        index = _groups.indexWhere((g) => g.name.trim().toLowerCase() == lower);
      }

      if (index >= 0) {
        final local = _groups[index];
        final next = List<String>.from(local.gameIds);
        var localChanged = false;
        for (final id in members) {
          if (next.contains(id)) continue;
          next.add(id);
          membershipUpdated++;
          localChanged = true;
        }
        if (localChanged) {
          _groups[index] = local.copyWith(gameIds: next);
          existingGroupsUpdated++;
          changed = true;
        }
        continue;
      }

      if (!canCreateGroup()) {
        skippedCreate++;
        continue;
      }

      final id = _allocateGroupId(preferred: pack.id);
      _groups.add(
        GameGroup(
          id: id,
          name: name,
          createdAt: pack.createdAt,
          gameIds: members,
        ),
      );
      created++;
      membershipUpdated += members.length;
      changed = true;
    }

    if (changed) {
      await _persist();
      notifyListeners();
    }
    return (
      created: created,
      membershipUpdated: membershipUpdated,
      existingGroupsUpdated: existingGroupsUpdated,
      skippedCreate: skippedCreate,
    );
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
