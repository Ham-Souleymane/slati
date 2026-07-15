import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'core/localization/app_localizations.dart';
import 'core/providers/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/location_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications service
  await NotificationService.instance.initialize();

  // Set system navigation/status bars styling
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  final sharedPrefs = await SharedPreferences.getInstance();

  // Initialize Firebase with defaults (uses instructions/placeholders or auto-configured ones)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize FCM and token sync after Firebase is initialized
    await NotificationService.instance.initializeFcm();
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
    debugPrint(
      'Make sure to set up your Firebase project and run "flutterfire configure" '
      'or add your config files as specified in FIREBASE_SETUP.md.',
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      child: const SalatiQourbakApp(),
    ),
  );
}

class SalatiQourbakApp extends ConsumerWidget {
  const SalatiQourbakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'صلاتي قربك',
      debugShowCheckedModeBanner: false,

      // ── Localization ──────────────────────────────────────────
      locale: locale,
      supportedLocales: const [
        Locale('ar', 'AE'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ── Theming ────────────────────────────────────────────────
      theme: AppTheme.light,

      // ── Router ─────────────────────────────────────────────────
      routerConfig: router,
    );
  }
}
