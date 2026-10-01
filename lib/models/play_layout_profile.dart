// User-customizable play-surface layout (normalized, device-independent).
// Defaults (empty / null fields) mean "use PlayLayout.resolve formulas as
// they ship today". Positions are centers in 0..1 of the play area.

/// Editable play-surface elements.
enum PlayElementId {
  game,
  dpad,
  faceA,
  faceB,
  shoulderL,
  shoulderR,
  select,
  start,
  menu,
  speed;

  /// Wire / JSON key (stable snake-free camel enum name).
  String get wireName => name;

  static PlayElementId? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // Legacy cluster key from v1 layouts.
    if (raw == 'face') return null;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  /// Human label for the editor chrome.
  String get label => switch (this) {
        PlayElementId.game => 'Game screen',
        PlayElementId.dpad => 'D-pad',
        PlayElementId.faceA => 'A',
        PlayElementId.faceB => 'B',
        PlayElementId.shoulderL => 'L',
        PlayElementId.shoulderR => 'R',
        PlayElementId.select => 'Select',
        PlayElementId.start => 'Start',
        PlayElementId.menu => 'Menu',
        PlayElementId.speed => 'Speed',
      };

  /// Soft min scale (max is resolved dynamically for [game]).
  double get minScale => switch (this) {
        PlayElementId.game => 0.4,
        _ => 0.5,
      };

  /// Soft max scale for non-game controls. Game max = fit play area edges.
  double get maxScaleSoft => switch (this) {
        PlayElementId.game => 4.0, // hard cap; real max is edge-fit
        _ => 2.5,
      };
}

/// Per-element transform. Null fields inherit the default layout.
class PlayElementTransform {
  const PlayElementTransform({
    this.centerX,
    this.centerY,
    this.scale,
  });

  /// Center X in 0..1 of play width. Null → default center.
  final double? centerX;

  /// Center Y in 0..1 of play height. Null → default center.
  final double? centerY;

  /// Multiplier on default size. Null or 1.0 → default size.
  final double? scale;

  static const empty = PlayElementTransform();

  bool get isDefault =>
      centerX == null &&
      centerY == null &&
      (scale == null || (scale! - 1.0).abs() < 1e-9);

  PlayElementTransform copyWith({
    double? centerX,
    double? centerY,
    double? scale,
    bool clearCenter = false,
    bool clearScale = false,
  }) {
    return PlayElementTransform(
      centerX: clearCenter ? null : (centerX ?? this.centerX),
      centerY: clearCenter ? null : (centerY ?? this.centerY),
      scale: clearScale ? null : (scale ?? this.scale),
    );
  }

  Map<String, Object?> toJson() {
    final m = <String, Object?>{};
    if (centerX != null) m['centerX'] = centerX;
    if (centerY != null) m['centerY'] = centerY;
    if (scale != null && (scale! - 1.0).abs() >= 1e-9) m['scale'] = scale;
    return m;
  }

  factory PlayElementTransform.fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final m = Map<String, Object?>.from(raw);
    double? read(String k) {
      final v = m[k];
      if (v is num) return v.toDouble();
      return null;
    }

    return PlayElementTransform(
      centerX: read('centerX'),
      centerY: read('centerY'),
      scale: read('scale'),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayElementTransform &&
          centerX == other.centerX &&
          centerY == other.centerY &&
          scale == other.scale;

  @override
  int get hashCode => Object.hash(centerX, centerY, scale);
}

/// Full layout profile persisted as `play_layout.json`.
class PlayLayoutProfile {
  const PlayLayoutProfile({this.elements = const {}});

  /// Empty map = stock layout (current [PlayLayout.resolve] formulas).
  static const defaults = PlayLayoutProfile();

  static const int formatVersion = 1;

  final Map<PlayElementId, PlayElementTransform> elements;

  bool get isDefault {
    if (elements.isEmpty) return true;
    for (final t in elements.values) {
      if (!t.isDefault) return false;
    }
    return true;
  }

  PlayElementTransform of(PlayElementId id) =>
      elements[id] ?? PlayElementTransform.empty;

  PlayLayoutProfile withElement(PlayElementId id, PlayElementTransform t) {
    final next = Map<PlayElementId, PlayElementTransform>.from(elements);
    if (t.isDefault) {
      next.remove(id);
    } else {
      next[id] = t;
    }
    return PlayLayoutProfile(elements: Map.unmodifiable(next));
  }

  PlayLayoutProfile reset() => defaults;

  Map<String, Object?> toJson() {
    final el = <String, Object?>{};
    for (final e in PlayElementId.values) {
      final t = elements[e];
      if (t == null || t.isDefault) continue;
      el[e.wireName] = t.toJson();
    }
    return {
      'version': formatVersion,
      'elements': el,
    };
  }

  factory PlayLayoutProfile.fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    final m = Map<String, Object?>.from(raw);
    final elRaw = m['elements'];
    if (elRaw is! Map) return defaults;
    final out = <PlayElementId, PlayElementTransform>{};
    for (final entry in elRaw.entries) {
      final key = entry.key.toString();
      // Legacy "face" cluster → scale-only on both A and B (positions stay default).
      if (key == 'face') {
        final t = PlayElementTransform.fromJson(entry.value);
        if (t.scale != null && (t.scale! - 1.0).abs() >= 1e-9) {
          final scaleOnly = PlayElementTransform(scale: t.scale);
          out[PlayElementId.faceA] = scaleOnly;
          out[PlayElementId.faceB] = scaleOnly;
        }
        continue;
      }
      final id = PlayElementId.tryParse(key);
      if (id == null) continue;
      final t = PlayElementTransform.fromJson(entry.value);
      if (!t.isDefault) out[id] = t;
    }
    if (out.isEmpty) return defaults;
    return PlayLayoutProfile(elements: Map.unmodifiable(out));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PlayLayoutProfile) return false;
    if (elements.length != other.elements.length) return false;
    for (final e in elements.entries) {
      if (other.elements[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        PlayElementId.values.map((id) => elements[id]),
      );
}
