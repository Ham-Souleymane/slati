import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/location_permission_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/mosques/presentation/nearby_mosques_screen.dart';
import '../../features/mosques/presentation/mosque_details_screen.dart';
import '../../features/prayer_times/presentation/full_prayer_times_screen.dart';
import '../../features/posts/presentation/feed_screen.dart';
import '../../features/posts/presentation/post_details_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/mosques/presentation/saved_mosques_screen.dart';
import '../../features/posts/domain/post_model.dart';
import '../../shared/widgets/scaffold_with_nav_bar.dart';

// ── Route names ───────────────────────────────────────────────
abstract class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const locationPermission = '/location-permission';
  static const home = '/home';
  static const nearbyMosques = '/nearby-mosques';
  static const mosqueDetails = '/mosque/:id';
  static const prayerTimes = '/prayer-times';
  static const feed = '/feed';
  static const postDetails = '/post/:id';
  static const profile = '/profile';
  static const savedMosques = '/saved-mosques';
}

// ── Router notifier ───────────────────────────────────────────
/// Holds the latest auth + location state and notifies GoRouter
/// to re-run redirect() whenever those values change — without
/// rebuilding the GoRouter instance itself.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    // Notify GoRouter when auth or location state changes.
    // We DEFER via addPostFrameCallback because ref.listen fires
    // synchronously during Riverpod's state propagation, which can coincide
    // with an active layout pass and trigger the !_debugDoingThisLayout
    // assertion in RenderObject.markNeedsLayout.
    _ref.listen(authStateChangesProvider, (_, __) => _scheduleNotify());
    _ref.listen(userLocationProvider, (_, __) => _scheduleNotify());
  }

  final Ref _ref;
  bool _pending = false;

  /// Coalesces multiple changes in the same frame into a single notify call
  /// that fires safely after layout + paint are complete.
  void _scheduleNotify() {
    if (_pending) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (hasListeners) notifyListeners();
    });
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;

    final authState = _ref.read(authStateChangesProvider);

    // Wait for Firebase auth to initialise
    if (authState.isLoading) {
      if (location != AppRoutes.splash) return AppRoutes.splash;
      return null;
    }

    final user = authState.asData?.value;
    final isLoggedIn = user != null; // includes anonymous users

    const publicRoutes = {
      AppRoutes.splash,
      AppRoutes.login,
      AppRoutes.register,
    };

    // 1. Unauthenticated → redirect to login (public routes exempt)
    if (!isLoggedIn) {
      if (!publicRoutes.contains(location)) return AppRoutes.login;
      return null;
    }

    final userLocation = _ref.read(userLocationProvider);

    // 2. Logged-in but location is unconfigured → force Location Permission
    if (userLocation == null) {
      if (location != AppRoutes.locationPermission) {
        return AppRoutes.locationPermission;
      }
      return null;
    }

    // 3. Logged-in with location → prevent going back to auth/location screens
    if (publicRoutes.contains(location) ||
        location == AppRoutes.locationPermission) {
      return AppRoutes.home;
    }

    return null;
  }
}

// ── Router provider ───────────────────────────────────────────
/// The GoRouter is created ONCE and never recreated. State changes
/// are handled via [_RouterNotifier] + refreshListenable.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Public / auth routes (no nav bar) ─────────────────────
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.locationPermission,
        name: 'locationPermission',
        builder: (context, state) => const LocationPermissionScreen(),
      ),

      // ── Mosque details & post details (full-screen, no nav bar) ─
      GoRoute(
        path: AppRoutes.mosqueDetails,
        name: 'mosqueDetails',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MosqueDetailsScreen(mosqueId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.postDetails,
        name: 'postDetails',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final post = state.extra as PostModel?;
          return PostDetailsScreen(postId: id, post: post);
        },
      ),
      GoRoute(
        path: AppRoutes.savedMosques,
        name: 'savedMosques',
        builder: (context, state) => const SavedMosquesScreen(),
      ),

      // ── Main app shell with floating nav bar ──────────────────
      ShellRoute(
        builder: (context, state, child) =>
            ScaffoldWithNavBar(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.prayerTimes,
            name: 'prayerTimes',
            builder: (context, state) => const FullPrayerTimesScreen(),
          ),
          GoRoute(
            path: AppRoutes.nearbyMosques,
            name: 'nearbyMosques',
            builder: (context, state) => const NearbyMosquesScreen(),
          ),
          GoRoute(
            path: AppRoutes.feed,
            name: 'feed',
            builder: (context, state) => const FeedScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );

  // Setup click action listeners for FCM
  NotificationService.instance.setupFcmNavigation(router);

  ref.onDispose(router.dispose);
  ref.onDispose(notifier.dispose);

  return router;
});
