import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/entitlements/pro_product.dart';
import 'pro_access.dart';

/// Terminal result of a buy / restore attempt (for Settings toasts).
enum ProBillingOutcome {
  /// Lifetime unlock applied (purchase or restore).
  unlocked,

  /// Already Pro before the call.
  alreadyPro,

  /// User closed the sheet or Play reported cancel.
  canceled,

  /// Hard failure (product missing, billing error, …).
  error,

  /// Restore finished with no entitlement found (timeout / empty).
  notFound,
}

/// Play Billing for lifetime Pro ([ProProduct.lifetimeId]).
///
/// Listens to [InAppPurchase.purchaseStream], unlocks [ProAccess] on
/// purchased/restored, and completes pending transactions.
///
/// Android often closes the billing sheet without a purchase-stream event
/// (USER_CANCELED). [onHostResumed] clears a stuck “buying” spinner — scoped
/// to the active buy generation so a second tap is not killed by a stale timer.
class ProBilling extends ChangeNotifier {
  ProBilling(this.pro);

  final ProAccess pro;
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  bool _available = false;
  bool _loading = false;
  bool _buying = false;
  bool _streamPending = false;
  String? _lastError;

  /// Monotonic id for the current buy sheet; resume fallback checks this.
  int _buyGeneration = 0;

  DateTime? _buyStartedAt;

  Completer<ProBillingOutcome>? _buyOutcome;
  Completer<ProBillingOutcome>? _restoreOutcome;

  ProductDetails? get product => _product;
  bool get available => _available;
  bool get loading => _loading;
  bool get buying => _buying;
  String? get lastError => _lastError;

  /// Localized price from Play, e.g. "39.000 ₫", or null if not loaded.
  String? get priceLabel => _product?.price;

  bool get canBuy =>
      _available && _product != null && !pro.isPro && !_buying && !_loading;

  /// Attach purchase stream and load product details. Safe on desktop (no-op).
  Future<void> start() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    _available = await _iap.isAvailable();
    if (!_available) {
      _lastError = 'Play Billing is not available on this device.';
      notifyListeners();
      return;
    }

    await _sub?.cancel();
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) {
        debugPrint('ProBilling.purchaseStream error: $e');
        _lastError = e.toString();
        _endBuying(ProBillingOutcome.error);
      },
    );

    await loadProduct();
    // Local Pro flag is a cache only — re-sync from Play when possible.
    unawaited(restore(silent: true));
  }

  Future<void> disposeBilling() async {
    await _sub?.cancel();
    _sub = null;
    _failPendingWaiters(ProBillingOutcome.canceled);
  }

  @override
  void dispose() {
    unawaited(disposeBilling());
    super.dispose();
  }

  /// Call when the app returns to foreground (billing sheet closed).
  void onHostResumed() {
    if (!_buying || pro.isPro || _streamPending) return;
    final started = _buyStartedAt;
    if (started == null) return;
    // Ignore resumes that fire before the sheet could have appeared.
    if (DateTime.now().difference(started) < const Duration(milliseconds: 250)) {
      return;
    }
    final gen = _buyGeneration;
    unawaited(_clearBuyingAfterSheetDismissed(gen));
  }

  Future<void> _clearBuyingAfterSheetDismissed(int generation) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    // Stale timer from a previous cancel must not kill a newer buy session.
    if (generation != _buyGeneration) return;
    if (!_buying || pro.isPro || _streamPending) return;
    debugPrint('ProBilling: clearing stuck buying after billing sheet dismiss');
    _lastError = null;
    _endBuying(ProBillingOutcome.canceled);
  }

  void _endBuying(ProBillingOutcome outcome) {
    _buying = false;
    _streamPending = false;
    _buyStartedAt = null;
    final c = _buyOutcome;
    _buyOutcome = null;
    if (c != null && !c.isCompleted) {
      c.complete(outcome);
    }
    notifyListeners();
  }

  void _failPendingWaiters(ProBillingOutcome outcome) {
    final b = _buyOutcome;
    _buyOutcome = null;
    if (b != null && !b.isCompleted) b.complete(outcome);
    final r = _restoreOutcome;
    _restoreOutcome = null;
    if (r != null && !r.isCompleted) r.complete(outcome);
  }

  Future<void> loadProduct() async {
    if (!_available) return;
    _loading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await _iap.queryProductDetails({ProProduct.lifetimeId});
      if (response.error != null) {
        _lastError = response.error!.message;
        _product = null;
      } else if (response.productDetails.isEmpty) {
        _lastError =
            'Product “${ProProduct.lifetimeId}” not found. '
            'Check Play Console (Active) and install from a testing track.';
        _product = null;
      } else {
        _product = response.productDetails.first;
        _lastError = null;
      }
    } catch (e) {
      _lastError = e.toString();
      _product = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Opens the Play purchase sheet (does not wait for the user to finish).
  Future<void> buy() async {
    if (pro.isPro) return;
    if (!_available) {
      _lastError = 'Play Billing is not available.';
      notifyListeners();
      return;
    }
    if (_product == null) {
      await loadProduct();
    }
    final details = _product;
    if (details == null) {
      notifyListeners();
      return;
    }

    _buyGeneration++;
    _buying = true;
    _streamPending = false;
    _buyStartedAt = DateTime.now();
    _lastError = null;
    notifyListeners();

    try {
      final param = PurchaseParam(productDetails: details);
      final ok = await _iap.buyNonConsumable(purchaseParam: param);
      if (!ok) {
        _lastError = 'Could not start purchase.';
        _endBuying(ProBillingOutcome.error);
      }
    } catch (e) {
      _lastError = e.toString();
      _endBuying(ProBillingOutcome.error);
    }
  }

  /// Opens the purchase sheet and waits for a terminal outcome (or cancel fallback).
  Future<ProBillingOutcome> buyAndAwait({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (pro.isPro) return ProBillingOutcome.alreadyPro;

    final completer = Completer<ProBillingOutcome>();
    _buyOutcome = completer;
    await buy();

    // buy() may have already completed with error (product missing / start fail).
    if (!_buying && completer.isCompleted) {
      return completer.future;
    }
    if (!_buying && !completer.isCompleted) {
      final outcome = _lastError != null
          ? ProBillingOutcome.error
          : ProBillingOutcome.canceled;
      completer.complete(outcome);
      _buyOutcome = null;
      return outcome;
    }

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _buyOutcome = null;
      if (pro.isPro) return ProBillingOutcome.unlocked;
      _endBuying(ProBillingOutcome.canceled);
      return ProBillingOutcome.canceled;
    }
  }

  /// Restores previous lifetime unlocks for this Google account.
  Future<void> restore({bool silent = false}) async {
    if (!_available) {
      if (!silent) {
        _lastError = 'Play Billing is not available.';
        notifyListeners();
      }
      return;
    }
    if (!silent) {
      _loading = true;
      _lastError = null;
      notifyListeners();
    }
    try {
      await _iap.restorePurchases();
    } catch (e) {
      if (!silent) {
        _lastError = e.toString();
      }
      debugPrint('ProBilling.restore: $e');
    } finally {
      if (!silent) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Restore and wait for stream unlock (or [notFound] / [error]).
  Future<ProBillingOutcome> restoreAndAwait({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (pro.isPro) return ProBillingOutcome.alreadyPro;
    if (!_available) {
      _lastError = 'Play Billing is not available.';
      notifyListeners();
      return ProBillingOutcome.error;
    }

    final completer = Completer<ProBillingOutcome>();
    _restoreOutcome = completer;

    void onPro() {
      if (pro.isPro && !completer.isCompleted) {
        completer.complete(ProBillingOutcome.unlocked);
      }
    }

    pro.addListener(onPro);
    _loading = true;
    _lastError = null;
    notifyListeners();

    try {
      await _iap.restorePurchases();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('ProBilling.restoreAndAwait: $e');
      pro.removeListener(onPro);
      _restoreOutcome = null;
      _loading = false;
      notifyListeners();
      return ProBillingOutcome.error;
    }

    _loading = false;
    notifyListeners();

    try {
      final outcome = await completer.future.timeout(
        timeout,
        onTimeout: () {
          if (pro.isPro) return ProBillingOutcome.unlocked;
          return ProBillingOutcome.notFound;
        },
      );
      return outcome;
    } finally {
      pro.removeListener(onPro);
      if (_restoreOutcome == completer) {
        _restoreOutcome = null;
      }
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    if (purchases.isEmpty) {
      if (_buying && !_streamPending) {
        _endBuying(ProBillingOutcome.canceled);
      }
      return;
    }

    var unlocked = false;
    var terminalCancelOrError = false;
    var sawPending = false;
    ProBillingOutcome? errorOutcome;

    for (final purchase in purchases) {
      final needsComplete = purchase.pendingCompletePurchase;

      // Strict: only our lifetime product can unlock Pro.
      if (purchase.productID != ProProduct.lifetimeId) {
        if (needsComplete) {
          try {
            await _iap.completePurchase(purchase);
          } catch (e) {
            debugPrint('ProBilling.completePurchase (other): $e');
          }
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await pro.setPro(true);
          unlocked = true;
          _lastError = null;
          _streamPending = false;
        case PurchaseStatus.pending:
          sawPending = true;
          _streamPending = true;
        case PurchaseStatus.error:
          _streamPending = false;
          if (_isUserCanceled(purchase.error)) {
            terminalCancelOrError = true;
            _lastError = null;
            errorOutcome = ProBillingOutcome.canceled;
          } else {
            terminalCancelOrError = true;
            _lastError = purchase.error?.message ?? 'Purchase failed.';
            errorOutcome = ProBillingOutcome.error;
          }
        case PurchaseStatus.canceled:
          _streamPending = false;
          terminalCancelOrError = true;
          _lastError = null;
          errorOutcome = ProBillingOutcome.canceled;
      }

      if (needsComplete) {
        try {
          await _iap.completePurchase(purchase);
        } catch (e) {
          debugPrint('ProBilling.completePurchase: $e');
        }
      }
    }

    if (unlocked) {
      _completeRestore(ProBillingOutcome.unlocked);
      _endBuying(ProBillingOutcome.unlocked);
      return;
    }

    if (terminalCancelOrError) {
      _endBuying(errorOutcome ?? ProBillingOutcome.canceled);
      return;
    }

    if (sawPending) {
      notifyListeners();
      return;
    }

    notifyListeners();
  }

  void _completeRestore(ProBillingOutcome outcome) {
    final c = _restoreOutcome;
    _restoreOutcome = null;
    if (c != null && !c.isCompleted) {
      c.complete(outcome);
    }
  }

  /// Play USER_CANCELED (1) / user-closed sheet — not a real error toast.
  static bool _isUserCanceled(IAPError? error) {
    if (error == null) return false;
    final code = error.code.toLowerCase();
    final msg = error.message.toLowerCase();
    if (code.contains('cancel') || msg.contains('cancel')) return true;
    // BillingClient.BillingResponseCode.USER_CANCELED == 1
    if (code == '1' || msg.contains('responsecode: 1')) return true;
    if (msg.contains('user') && msg.contains('cancel')) return true;
    return false;
  }
}
