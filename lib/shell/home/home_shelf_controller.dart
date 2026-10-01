import 'package:flutter/foundation.dart';

/// Canonical home shelf session state: focus, busy gate, import chrome.
///
/// Absolute [focusedId] only — screens never dual-toggle. Library reports
/// set/clear; home applies the same value.
class HomeShelfController extends ChangeNotifier {
  String? _focusedId;
  bool _busy = false;
  String? _importingId;

  String? get focusedId => _focusedId;
  bool get busy => _busy;
  String? get importingId => _importingId;

  /// Absolute focus (null = none). No-op when unchanged.
  void setFocusedId(String? id) {
    if (_focusedId == id) return;
    _focusedId = id;
    notifyListeners();
  }

  /// Shelf/grid tap: same id clears, else focuses that game.
  void toggleFocus(String gameId) {
    setFocusedId(_focusedId == gameId ? null : gameId);
  }

  void clearFocus() => setFocusedId(null);

  void setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  /// Focus + brief tile progress after a successful import.
  void beginImportProgress(String gameId) {
    _importingId = gameId;
    _focusedId = gameId;
    notifyListeners();
  }

  void endImportProgress(String gameId) {
    if (_importingId != gameId) return;
    _importingId = null;
    notifyListeners();
  }

  void clearImportIf(String gameId) {
    if (_importingId != gameId) return;
    _importingId = null;
    notifyListeners();
  }

  /// Drop focus when the game left the library.
  void dropFocusIfMissing(bool Function(String id) exists) {
    final id = _focusedId;
    if (id == null || exists(id)) return;
    _focusedId = null;
    notifyListeners();
  }
}
