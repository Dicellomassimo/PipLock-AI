import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

// Lingue supportate dall'app (deve corrispondere a supportedLanguages in app_strings.dart)
const _supportedCodes = {
  'en', 'it', 'es', 'pt', 'fr', 'de', 'nl', 'pl', 'ru', 'uk',
  'tr', 'ar', 'zh', 'ja', 'ko', 'hi', 'id', 'sv', 'ro', 'cs', 'el', 'da',
};

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLocaleKey);

    if (saved != null) {
      // L'utente ha già scelto manualmente — rispetta la sua scelta
      state = Locale(saved);
      return;
    }

    // Prima installazione: rileva la lingua del device e usala se supportata
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final deviceCode = deviceLocale.languageCode;
    if (_supportedCodes.contains(deviceCode)) {
      state = Locale(deviceCode);
      await prefs.setString(_kLocaleKey, deviceCode);
    } else {
      state = const Locale('en');
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);
