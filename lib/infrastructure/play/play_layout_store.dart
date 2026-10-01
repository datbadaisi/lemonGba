import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/play_layout_profile.dart';
import '../storage/save_paths.dart';

/// Persistent [PlayLayoutProfile] (`play_layout.json` under [SavePaths.root]).
///
/// Writes only happen on explicit [save] / [reset] — no auto-debounce.
class PlayLayoutStore extends ChangeNotifier {
  PlayLayoutStore._(this._file);

  final File _file;
  PlayLayoutProfile _profile = PlayLayoutProfile.defaults;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  PlayLayoutProfile get profile => _profile;

  static Future<PlayLayoutStore> open(SavePaths paths) async {
    final store = PlayLayoutStore._(paths.playLayoutFile);
    await store.load();
    return store;
  }

  Future<void> load() async {
    try {
      if (await _file.exists()) {
        final decoded = jsonDecode(await _file.readAsString());
        _profile = PlayLayoutProfile.fromJson(decoded);
      } else {
        _profile = PlayLayoutProfile.defaults;
      }
    } catch (e) {
      debugPrint('PlayLayoutStore.load: $e');
      _profile = PlayLayoutProfile.defaults;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Persist [next] immediately (user tapped Save).
  Future<void> save(PlayLayoutProfile next) async {
    _profile = next;
    notifyListeners();
    await _persist();
  }

  /// Restore stock layout and write to disk immediately.
  Future<void> reset() async {
    _profile = PlayLayoutProfile.defaults;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _file.parent.create(recursive: true);
      await _file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_profile.toJson()),
      );
    } catch (e) {
      debugPrint('PlayLayoutStore.persist: $e');
    }
  }
}
