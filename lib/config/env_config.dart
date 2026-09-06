/// Compile-time environment configuration for PipLock AI.
///
/// Values are injected at build time via --dart-define-from-file=secrets.json
/// (recommended) or individually with --dart-define=KEY=value.
///
/// The secrets.json file is NEVER bundled into the APK — it stays local.
/// Copy secrets.json.example → secrets.json and fill in your values.
///
/// Build examples:
///   flutter run   --dart-define-from-file=secrets.json
///   flutter build apk --release --dart-define-from-file=secrets.json
class EnvConfig {
  const EnvConfig._();

  static const supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');

  static const supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static const finnhubApiKey =
      String.fromEnvironment('FINNHUB_API_KEY');

  static const metaApiToken =
      String.fromEnvironment('METAAPI_TOKEN');

  static const googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Public API key per l'SDK RevenueCat (formato goog_xxxx).
  /// Recuperalo da RevenueCat dashboard → Apps → [tua app Android] → Public API key.
  static const revenueCatPublicKey =
      String.fromEnvironment('REVENUECAT_PUBLIC_KEY');

  /// Secret API key server-side (sk_...). NON va nell'app — usarla solo
  /// in Supabase Edge Functions per validare i webhook RevenueCat.
  static const revenueCatSecretKey =
      String.fromEnvironment('REVENUECAT_API_KEY');

  /// True when the minimum required configuration is present.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
