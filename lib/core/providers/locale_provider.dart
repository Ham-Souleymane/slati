import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/location_service.dart';

/// The key used to persist the locale choice in SharedPreferences.
const _kLocaleKey = 'app_locale_language_code';

/// Notifier that manages the current app [Locale] and persists it.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(_kLocaleKey);
    if (saved != null && ['ar', 'en'].contains(saved)) {
      return Locale(saved);
    }
    // Default to Arabic
    return const Locale('ar', 'AE');
  }

  /// Switch the app locale and persist the choice.
  Future<void> setLocale(Locale locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kLocaleKey, locale.languageCode);
    state = locale;
  }
}

/// Provider for the current app locale.
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
