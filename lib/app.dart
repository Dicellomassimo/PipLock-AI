import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/app_colors.dart';
import 'config/app_strings.dart';
import 'config/app_theme.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/nav/main_nav_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/ai_planner/ai_planner_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/notifications/notification_settings_screen.dart';
import 'screens/setup/challenges_screen.dart';
import 'screens/tokens/tokens_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/setup/personal_rules_screen.dart';
import 'screens/setup/challenge_setup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/broker/broker_screen.dart';
import 'screens/settings/permissions_screen.dart';
import 'screens/account/account_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/observer/observer_screen.dart';
import 'screens/journal/journal_screen.dart';
import 'screens/journal/journal_entry_form_screen.dart';
import 'screens/paywall/paywall_screen.dart';
import 'screens/killswitch/trading_hours_block_screen.dart';
import 'screens/setup/setup_wizard_screen.dart';

// Re-esporta kDevMode per compatibilità con altri file che lo importano da app.dart
export 'config/constants.dart' show kDevMode;

class PipLockApp extends StatelessWidget {
  const PipLockApp({super.key});

  static Route<T> _slideUpRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, anim, _) => page,
      transitionDuration: AppTheme.dMedium,
      reverseTransitionDuration: AppTheme.dFast,
      transitionsBuilder: (_, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: AppTheme.cSpring)),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }

  static Route<T> _fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, anim, _) => page,
      transitionDuration: AppTheme.dMedium,
      reverseTransitionDuration: AppTheme.dFast,
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          final locale = ref.watch(localeProvider);
          final isDark = ref.watch(themeProvider);
          return MaterialApp(
            title: 'PipLock AI',
            debugShowCheckedModeBanner: false,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            theme: _buildLightTheme(),
            darkTheme: _buildTheme(),
            locale: locale,
            supportedLocales: const [
              Locale('en'),
              Locale('it'),
              Locale('es'),
              Locale('pt'),
              Locale('fr'),
              Locale('de'),
              Locale('nl'),
              Locale('pl'),
              Locale('ru'),
              Locale('uk'),
              Locale('tr'),
              Locale('ar'),
              Locale('zh'),
              Locale('ja'),
              Locale('ko'),
              Locale('hi'),
              Locale('id'),
              Locale('sv'),
              Locale('ro'),
              Locale('cs'),
              Locale('el'),
              Locale('da'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashScreen(),
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/onboarding':
                  return _slideUpRoute(const OnboardingScreen());
                case '/paywall':
                  return _slideUpRoute(const PaywallScreen());
                case '/setup_wizard':
                  return _slideUpRoute(const SetupWizardScreen());
                default:
                  return null; // fallback alle routes statiche
              }
            },
            routes: {
              '/auth': (_) => const AuthScreen(),
              '/main': (_) => const MainNavScreen(),
              '/dashboard': (_) => const MainNavScreen(), // compatibilità
              '/ai_planner': (_) => const AiPlannerScreen(),
              '/history': (_) => const HistoryScreen(),
              '/notifications': (_) => const NotificationsScreen(),
              '/tokens': (_) => const TokensScreen(),
              '/buy_tokens': (_) => const TokensScreen(), // redirected — no purchase
              '/settings': (_) => const SettingsScreen(),
              '/personal_rules': (_) => const PersonalRulesScreen(),
              '/challenge_setup': (_) => const ChallengeSetupScreen(),
              '/forgot_password': (_) => const ForgotPasswordScreen(),
              '/broker': (_) => const BrokerScreen(),
              '/permissions': (_) => const PermissionsScreen(),
              '/account': (_) => const AccountScreen(),
              '/profile': (_) => const ProfileScreen(),
              '/notification_settings': (_) => const NotificationSettingsScreen(),
              '/challenges': (_) => const ChallengesScreen(),
              '/observer': (_) => const ObserverScreen(),
              '/journal': (_) => const JournalScreen(),
              '/journal/add': (_) => const JournalEntryFormScreen(),
              '/auth-callback': (_) => const _AuthCallbackScreen(),
              '/trading_hours_block': (ctx) {
                final args = ModalRoute.of(ctx)!.settings.arguments
                    as Map<String, dynamic>? ?? {};
                final start = args['tradingStart'] as TimeOfDay?
                    ?? const TimeOfDay(hour: 8, minute: 0);
                final end = args['tradingEnd'] as TimeOfDay?
                    ?? const TimeOfDay(hour: 18, minute: 0);
                return TradingHoursBlockScreen(
                    tradingStart: start, tradingEnd: end);
              },
            },
          );
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.warning,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      textTheme: GoogleFonts.manropeTextTheme(
        ThemeData.dark().textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
        actionsIconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
        titleTextStyle: GoogleFonts.manrope(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: -0.4,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accent.withValues(alpha: 0.12),
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.manrope(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            );
          }
          return GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          );
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.black;
          return AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.divider;
        }),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.divider,
        thumbColor: AppColors.accent,
        overlayColor: Color(0x207B61FF),
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBg,
        hintStyle: GoogleFonts.manrope(
          color: AppColors.textTertiary,
          fontSize: 15,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),
      dividerColor: AppColors.divider,
      cardColor: AppColors.cardBg,
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.warning,
        surface: AppColors.lightSurface,
        error: AppColors.danger,
      ),
      textTheme: GoogleFonts.manropeTextTheme(
        ThemeData.light().textTheme.apply(
          bodyColor: AppColors.lightTextPrimary,
          displayColor: AppColors.lightTextPrimary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.lightTextSecondary, size: 22),
        actionsIconTheme: const IconThemeData(color: AppColors.lightTextSecondary, size: 22),
        titleTextStyle: GoogleFonts.manrope(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: -0.4,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.accent.withValues(alpha: 0.15),
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.manrope(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            );
          }
          return GoogleFonts.manrope(
            color: AppColors.lightTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          );
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.lightTextSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.lightDivider;
        }),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.lightDivider,
        thumbColor: AppColors.accent,
        overlayColor: Color(0x207B61FF),
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightCardBg,
        hintStyle: GoogleFonts.manrope(
          color: AppColors.lightTextTertiary,
          fontSize: 15,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        prefixIconColor: AppColors.lightTextSecondary,
        suffixIconColor: AppColors.lightTextSecondary,
      ),
      dividerColor: AppColors.lightDivider,
      cardColor: AppColors.lightCardBg,
    );
  }
}

class _AuthCallbackScreen extends ConsumerWidget {
  const _AuthCallbackScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, color: AppColors.accent, size: 64),
            const SizedBox(height: 16),
            Text(
              s.authComplete,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.redirecting,
              style: GoogleFonts.manrope(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
