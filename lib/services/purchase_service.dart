import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gestisce acquisti in-app via Google Play Billing (in_app_purchase).
///
/// Prodotti:
///   - 'piplock_pro_monthly'  → abbonamento mensile €9.99 (7 giorni trial)
///   - 'piplock_pro_annual'   → abbonamento annuale €83.88 (7 giorni trial)
///   - 'piplock_token_1'      → 1 token (consumable)
///   - 'piplock_token_3'      → 3 token (consumable)
///   - 'piplock_token_5'      → 5 token (consumable)
class PurchaseService {
  static const _proIds = {'piplock_pro_monthly', 'piplock_pro_annual'};
  static const _tokenIds = {'piplock_token_1', 'piplock_token_3', 'piplock_token_5'};
  static const _allIds = {
    'piplock_pro_monthly',
    'piplock_pro_annual',
    'piplock_token_1',
    'piplock_token_3',
    'piplock_token_5',
  };

  static final InAppPurchase _iap = InAppPurchase.instance;

  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static List<ProductDetails> _products = [];
  static bool _initialized = false;

  // Completer per attendere il risultato di un acquisto in corso
  static Completer<bool>? _proCompleter;
  static Completer<int>? _tokenCompleter;

  // ── Inizializzazione ───────────────────────────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;

    final available = await _iap.isAvailable();
    if (!available) {
      // Store non disponibile (emulatore senza Play Store) — mock mode
      _initialized = true;
      return;
    }

    // Ascolta lo stream degli acquisti
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (_) {},
    );

    // Carica i prodotti
    final response = await _iap.queryProductDetails(_allIds);
    _products = response.productDetails;

    _initialized = true;
  }

  // ── Stream handler ─────────────────────────────────────────────────────────

  static Future<void> _onPurchaseUpdate(
      List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Completa la transazione con il Play Store
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }

        final id = purchase.productID;

        if (_proIds.contains(id)) {
          await _updateSupabasePro();
          _proCompleter?.complete(true);
          _proCompleter = null;
        } else if (_tokenIds.contains(id)) {
          final tokens = _tokensForProduct(id);
          await _updateSupabaseTokens(tokens);
          _tokenCompleter?.complete(tokens);
          _tokenCompleter = null;
        }
      } else if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        _proCompleter?.complete(false);
        _proCompleter = null;
        _tokenCompleter?.complete(0);
        _tokenCompleter = null;
      }
    }
  }

  // ── API pubblica ───────────────────────────────────────────────────────────

  /// Acquista un abbonamento Pro. Ritorna true se andato a buon fine.
  static Future<bool> purchasePro(
      [String productId = 'piplock_pro_monthly']) async {
    // Mock mode: store non disponibile
    if (!_initialized || !(await _iap.isAvailable())) {
      return true;
    }

    final product = _findProduct(productId);
    if (product == null) return false;

    _proCompleter = Completer<bool>();

    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);

    return _proCompleter!.future;
  }

  /// Acquista token consumable. Ritorna il numero di token aggiunti (0 se fallisce).
  static Future<int> purchaseTokens(String productId) async {
    // Mock mode
    if (!_initialized || !(await _iap.isAvailable())) {
      return _tokensForProduct(productId);
    }

    final product = _findProduct(productId);
    if (product == null) return 0;

    _tokenCompleter = Completer<int>();

    final param = PurchaseParam(productDetails: product);
    await _iap.buyConsumable(purchaseParam: param);

    return _tokenCompleter!.future;
  }

  /// Ripristina acquisti precedenti. Ritorna true se trovati acquisti attivi.
  static Future<bool> restorePurchases() async {
    if (!_initialized || !(await _iap.isAvailable())) return false;
    try {
      await _iap.restorePurchases();
      // Il risultato arriva tramite il purchaseStream (_onPurchaseUpdate)
      return await checkProStatus();
    } catch (_) {
      return false;
    }
  }

  /// Verifica se l'utente ha Pro attivo leggendo Supabase.
  static Future<bool> checkProStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;
      final data = await Supabase.instance.client
          .from('profiles')
          .select('subscription_tier')
          .eq('id', userId)
          .maybeSingle();
      return data?['subscription_tier'] == 'pro';
    } catch (_) {
      return false;
    }
  }

  /// Cancella la subscription allo stream (chiamare in dispose).
  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _products = [];
  }

  // ── Helpers privati ────────────────────────────────────────────────────────

  static ProductDetails? _findProduct(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  static int _tokensForProduct(String id) {
    if (id.contains('token_1')) return 1;
    if (id.contains('token_3')) return 3;
    if (id.contains('token_5')) return 5;
    return 0;
  }

  static Future<void> _updateSupabasePro() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client
          .from('profiles')
          .update({'subscription_tier': 'pro'}).eq('id', userId);
    } catch (_) {}
  }

  static Future<void> _updateSupabaseTokens(int tokensToAdd) async {
    if (tokensToAdd <= 0) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final current = await Supabase.instance.client
          .from('profiles')
          .select('tokens_available')
          .eq('id', userId)
          .single();
      final newCount =
          (current['tokens_available'] as int? ?? 0) + tokensToAdd;
      await Supabase.instance.client
          .from('profiles')
          .update({'tokens_available': newCount}).eq('id', userId);
    } catch (_) {}
  }
}
