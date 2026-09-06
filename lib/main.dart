import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'config/constants.dart';
import 'config/env_config.dart';
import 'services/metaapi_service.dart';
import 'services/notification_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (_) {
    // google-services.json potrebbe non essere configurato completamente
  }

  // Failsafe: kDevMode non deve mai essere true in production.
  // Siccome è una const, questa condizione viene eliminata dal compilatore
  // quando kDevMode = false — zero overhead in release.
  if (kReleaseMode && kDevMode) {
    throw StateError(
        'SECURITY: kDevMode è true in un build di release. '
        'Imposta kDevMode = false in lib/config/constants.dart.');
  }

  assert(EnvConfig.isConfigured,
      'Missing SUPABASE_URL or SUPABASE_ANON_KEY — '
      'build with: flutter run --dart-define-from-file=secrets.json');

  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: EnvConfig.supabaseAnonKey,
  );

  // Handle deep links for email confirmation and password reset
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) async {
    if (uri.scheme == 'piplock') {
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      } catch (_) {}
    }
  });

  MetaApiService.setToken(EnvConfig.metaApiToken);

  if (EnvConfig.finnhubApiKey.isNotEmpty) {
    NotificationService.setFinnhubKey(EnvConfig.finnhubApiKey);
  }

  await NotificationService.initialize().timeout(
    const Duration(seconds: 6),
    onTimeout: () {},
  );
  NotificationService.startFinnhubMonitoring();
  // NOTE: scheduleUpcomingNotifications() is called in MainNavScreen.initState()
  // (after the user is on the main screen and the network is ready).

  // In release mode Flutter shows a white screen on uncaught widget errors.
  // This fallback shows a dark recovery card instead of crashing silently.
  // Cannot use Riverpod providers here (ProviderScope not yet in tree),
  // so we detect the system language from the platform dispatcher.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final lang = WidgetsBinding
        .instance.platformDispatcher.locale.languageCode;
    final isIt = lang == 'it';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFF9500), size: 48),
                const SizedBox(height: 16),
                Text(
                  isIt ? 'Qualcosa è andato storto' : 'Something went wrong',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isIt ? 'Riavvia l\'app.' : 'Please restart the app.',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  runApp(const PipLockApp());
}
