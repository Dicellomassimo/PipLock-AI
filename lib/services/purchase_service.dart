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
/// disponibile su RevenueCat Dashboard → Apps → [tua app Android] → Public API key.
/// La sk_... key va in Supabase Edge Functions (server-side), NON qui.
class PurchaseService {
  static const _proEntitlement = 'pro';
  static bool _initialized = false;
  // Cache prezzi fetched da RevenueCat per mostrarli nella paywall
  static String? _monthlyPriceString;
  static String? _annualPriceString;

  // ── Inizializzazione ───────────────────────────────────────────────────────

  /// Inizializzazione anonima — solo per caricare le offerings/prezzi
  /// prima che l'utente faccia login. Sicura da chiamare senza userId.
  static Future<void> initializeAnonymous() async {
    if (_initialized) return;
    final publicKey = EnvConfig.revenueCatPublicKey;
    if (publicKey.isEmpty || publicKey.startsWith('test_')) return;
    try {
      await Purchases.configure(PurchasesConfiguration(publicKey));
      _initialized = true;
      _loadPriceCache();
    } catch (_) {}
  }

  static Future<void> initialize({required String userId}) async {
    final publicKey = EnvConfig.revenueCatPublicKey;
    if (publicKey.isEmpty || publicKey.startsWith('test_')) return;

    try {
      if (!_initialized) {
        final config = PurchasesConfiguration(publicKey)..appUserID = userId;
        await Purchases.configure(config);
        _initialized = true;
      } else {
        // Era già inizializzato anonimamente: identifica l'utente ora
        await Purchases.logIn(userId);
      }

      // Sincronizza lo stato Pro a Supabase ogni volta che cambia
      Purchases.addCustomerInfoUpdateListener((info) {
        _syncProToSupabase(
          info.entitlements.active.containsKey(_proEntitlement),
        );
      });
      _loadPriceCache();
    } catch (_) {
      // RevenueCat non disponibile (emulatore, region, ecc.) — continua
    }
  }

  // Scarica e memorizza i prezzi in cache per uso sincrono nella UI
  static Future<void> _loadPriceCache() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return;
      _monthlyPriceString = current.monthly?.storeProduct.priceString;
      _annualPriceString = current.annual?.storeProduct.priceString;
    } catch (_) {}
  }

  /// Prezzo mensile da Play Store (null se non disponibile → usa fallback hardcoded)
  static String? get monthlyPriceString => _monthlyPriceString;

  /// Prezzo annuale da Play Store (null se non disponibile → usa fallback hardcoded)
  static String? get annualPriceString => _annualPriceString;

  // ── API pubblica ───────────────────────────────────────────────────────────

  /// Acquista un abbonamento Pro. Ritorna true se andato a buon fine.
  /// [isAnnual] true = piano annuale, false = piano mensile.
  static Future<bool> purchasePro({bool isAnnual = false}) async {
    if (!_initialized) return false; // Non mock: senza RC configurato non acquistare

    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return false;

      final package = isAnnual
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
