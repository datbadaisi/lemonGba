import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/entitlements/free_limits.dart';
import '../storage/save_paths.dart';

/// Lifetime Pro entitlement flag (local cache).
///
/// **Client-only design:** [isPro] is persisted in app files (`entitlements.json`)
/// for offline feature access. The real purchase lives on the user's
/// Google Play account. [ProBilling] re-syncs via silent restore on cold start.
///
/// Known tradeoff: a modified APK or edited `entitlements.json` can spoof Pro
/// until/unless you add server-side verification. Acceptable for this app.
///
/// Unlocked via Play Billing ([ProBilling]) or debug toggle in debug builds.
class ProAccess extends ChangeNotifier {
  ProAccess._(this._file);

  final File _file;
  bool _isPro = false;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// True after lifetime unlock (or debug toggle). Cache only — not a receipt.
  bool get isPro => _isPro;

  int get maxAvatars => isPro ? -1 : FreeLimits.maxAvatars;
  int get maxCovers => isPro ? -1 : FreeLimits.maxCovers;
  int get maxGroups => isPro ? -1 : FreeLimits.maxGroups;

  static Future<ProAccess> open(SavePaths paths) async {
    final file = File(p.join(paths.root.path, 'entitlements.json'));
    final access = ProAccess._(file);
    await access.load();
    return access;
  }

  Future<void> load() async {
    try {
      if (await _file.exists()) {
        final decoded = jsonDecode(await _file.readAsString());
        if (decoded is Map) {
          final v = decoded['isPro'];
          _isPro = v == true;
        }
      }
    } catch (e) {
      debugPrint('ProAccess.load: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  /// Persist Pro state (purchase success, restore, or debug toggle).
  Future<void> setPro(bool value) async {
    if (_isPro == value) return;
    _isPro = value;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _file.parent.create(recursive: true);
      await _file.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'isPro': _isPro,
          'productId': _isPro ? 'pro_lifetime' : null,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('ProAccess.persist: $e');
    }
  }
}
