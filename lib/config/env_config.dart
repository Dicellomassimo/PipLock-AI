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

  static const groqApiKey =
      String.fromEnvironment('GROQ_API_KEY');

  static const finnhubApiKey =
      String.fromEnvironment('FINNHUB_API_KEY');

  static const metaApiToken =
      String.fromEnvironment('METAAPI_TOKEN');

  static const googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static const revenueCatApiKey =
      String.fromEnvironment('REVENUECAT_API_KEY');

  /// True when the minimum required configuration is present.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
