import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';

/// Gestisce l'abbonamento Pro tramite RevenueCat SDK (purchases_flutter).
///
/// I token killswitch sono fissi: 2/settimana per tutti gli utenti, nessun acquisto.
/// RevenueCat gestisce solo l'entitlement Pro (AI Planner, analytics avanzate).
///
/// Prodotti attesi su RevenueCat dashboard:
///   - Entitlement: 'pro'
///   - Offerings: 'default' con package Monthly e Annual
///
/// NOTA: revenueCatPublicKey deve essere la Public API Key (formato goog_xxxx)
/// disponibile su RevenueCat Dashboard → Apps → [app Android] → Public API key.
/// La sk_... key va in Supabase Edge Functions (server-side), NON qui.
class PurchaseService {
  static const _proEntitlement = 'pro';
  static bool _initialized = false;

  // ── Inizializzazione ───────────────────────────────────────────────────────

  static Future<void> initialize({required String userId}) async {
    if (_initialized) return;

    final publicKey = EnvConfig.revenueCatPublicKey;
    // Skip se chiave non configurata o è una chiave di test (test_...)
    if (publicKey.isEmpty || publicKey.startsWith('test_')) return;

    try {
      final config = PurchasesConfiguration(publicKey)..appUserID = userId;
      await Purchases.configure(config);
      _initialized = true;

      // Sincronizza lo stato Pro a Supabase ogni volta che cambia
      Purchases.addCustomerInfoUpdateListener((info) {
        _syncProToSupabase(
          info.entitlements.active.containsKey(_proEntitlement),
        );
      });
    } catch (_) {
      // RevenueCat non disponibile (emulatore, region, ecc.) — continua
    }
  }

  // ── API pubblica ───────────────────────────────────────────────────────────

  /// Acquista un abbonamento Pro. Ritorna true se andato a buon fine.
  static Future<bool> purchasePro([
    String productId = 'piplock_pro_monthly',
  ]) async {
    if (!_initialized) return _mockPurchase();

    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return false;

      final package = productId.contains('annual')
          ? (current.annual ?? _firstPackage(current))
          : (current.monthly ?? _firstPackage(current));
      if (package == null) return false;

      final result = await Purchases.purchase(PurchaseParams.package(package));
      final isPro = result.customerInfo.entitlements.active.containsKey(_proEntitlement);
      if (isPro) await _syncProToSupabase(true);
      return isPro;
    } catch (_) {
      return false;
    }
  }

/// Ripristina acquisti precedenti. Ritorna true se trovati acquisti Pro attivi.
  static Future<bool> restorePurchases() async {
    if (!_initialized) return false;
    try {
      final info = await Purchases.restorePurchases();
      final isPro = info.entitlements.active.containsKey(_proEntitlement);
      if (isPro) await _syncProToSupabase(true);
      return isPro;
    } catch (_) {
      return false;
    }
  }

  /// Verifica stato Pro: prima da RevenueCat, poi da Supabase come fallback.
  static Future<bool> checkProStatus() async {
    if (_initialized) {
      try {
        final info = await Purchases.getCustomerInfo();
        return info.entitlements.active.containsKey(_proEntitlement);
      } catch (_) {}
    }
    // Fallback Supabase
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

  static void dispose() {
    _initialized = false;
  }

  // ── Helpers privati ────────────────────────────────────────────────────────

  static Package? _firstPackage(Offering offering) {
    return offering.availablePackages.isNotEmpty
        ? offering.availablePackages.first
        : null;
  }

  /// Mock per emulatori/environment senza Play Store configurato.
  static bool _mockPurchase() => true;

  static Future<void> _syncProToSupabase(bool isPro) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client
          .from('profiles')
          .update({'subscription_tier': isPro ? 'pro' : 'free'}).eq(
              'id', userId);
    } catch (_) {}
  }

}
