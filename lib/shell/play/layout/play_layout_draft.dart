import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Offset;

import '../../../infrastructure/play/play_layout_store.dart';
import '../../../models/play_layout_profile.dart';
import 'play_layout.dart';
import 'play_layout_resize.dart';

/// Draft layout edits + selection. Persist only via [saveTo].
class PlayLayoutDraft extends ChangeNotifier {
  PlayLayoutDraft(this._store) : _profile = _store.profile;

  final PlayLayoutStore _store;
  PlayLayoutProfile _profile;
  PlayElementId? _selected;

  LayoutResizeSession? _resize;

  /// Pinch base scale for the active resize session (game).
  double _pinchBaseScale = 1.0;

  PlayLayoutProfile get profile => _profile;
  PlayElementId? get selected => _selected;
  bool get isDirty => _profile != _store.profile;
  LayoutResizeSession? get resizeSession => _resize;

  PlayLayout resolve({
    required double width,
    required double height,
    required double bottomSafe,
  }) {
    return PlayLayout.resolve(
      width: width,
      height: height,
      bottomSafe: bottomSafe,
      profile: _profile,
    );
  }

  void select(PlayElementId id) {
    if (_selected == id) return;
    _selected = id;
    notifyListeners();
  }

  void deselect() {
    if (_selected == null) return;
    _selected = null;
    notifyListeners();
  }

  void patch(PlayElementId id, PlayElementTransform t) {
    _profile = _profile.withElement(id, t);
    notifyListeners();
  }

  void moveBy(PlayElementId id, Offset delta, PlayLayout layout) {
    if (_resize != null) return;
    final rect = layout.rectOf(id);
    final next = rect.center + delta;
    patch(
      id,
      _profile.of(id).copyWith(
            centerX: (next.dx / layout.width).clamp(0.0, 1.0),
            centerY: (next.dy / layout.height).clamp(0.0, 1.0),
          ),
    );
  }

  void beginResize(PlayElementId id, PlayLayout layout) {
    _resize = LayoutResizeSession.begin(id: id, layout: layout);
    _pinchBaseScale = _resize!.clampedScale(_profile.of(id).scale ?? 1.0);
    if (_selected != id) _selected = id;
    notifyListeners();
  }

  void updateResizeFromPointer(Offset localPos) {
    final s = _resize;
    if (s == null) return;
    patch(s.id, s.transformForPointer(localPos));
  }

  void updateResizeFromPinch(double gestureScale) {
    final s = _resize;
    if (s == null) return;
    patch(
      s.id,
      s.transformForPinch(
        baseScale: _pinchBaseScale,
        gestureScale: gestureScale,
      ),
    );
  }

  void endResize() {
    if (_resize == null) return;
    _resize = null;
    notifyListeners();
  }

  void resetDraft() {
    _profile = PlayLayoutProfile.defaults;
    _selected = null;
    _resize = null;
    notifyListeners();
  }

  Future<void> saveToStore() => _store.save(_profile);
}
