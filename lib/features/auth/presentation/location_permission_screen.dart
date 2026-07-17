import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/services/location_service.dart';
import '../../auth/data/user_repository.dart';

class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  ConsumerState<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState
    extends ConsumerState<LocationPermissionScreen> {
  bool _isLoading = false;

  // ── Native Permission Request ────────────────────────────────
  Future<void> _requestLocation() async {
    final myLocationText = context.tr('loc_my_location');
    setState(() => _isLoading = true);
    final locService = ref.read(locationServiceProvider);

    try {
      final isGranted = await locService.requestPermission();
      if (isGranted) {
        final pos = await locService.getCurrentPosition();
        if (pos != null) {
          final newLoc = UserLocation(
            latitude: pos.latitude,
            longitude: pos.longitude,
            name: myLocationText,
            isGps: true,
          );


          // Save state reactively & persist.
          // GoRouter's _RouterNotifier listens to userLocationProvider and
          // automatically redirects to /home when it becomes non-null.
          // Do NOT call context.go here — that would cause a double-navigation
          // layout crash (!_debugDoingThisLayout assertion).
          await ref.read(userLocationProvider.notifier).setLocation(newLoc);

          // Optionally update Firestore city for real (non-guest) users.
          final user = ref.read(firebaseAuthProvider).currentUser;
          if (user != null && !user.isAnonymous) {
            try {
              await ref.read(userRepositoryProvider).updateUserDoc(
                user.uid,
                {'city': 'GPS'},
              );

            } catch (e) {
              debugPrint('Warning: Could not update city in Firestore: $e');
            }
          }
          return;
        }
      }

      // If denied or GPS failed, show small alert and let user try manually
      if (mounted) {
        context.showSnackBar(
          context.tr('loc_permission_failed'),
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(context.tr('loc_error'), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── Manual City Selection ────────────────────────────────────
  void _selectCityManually() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ManualCityPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Friendly location-map illustration representation
              Center(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.emerald, AppColors.emeraldMedium],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald.withValues(alpha: 0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Radial ripples representation
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Mosque & Location Pin merged symbol
                      const Icon(
                        Icons.my_location_rounded,
                        color: AppColors.gold,
                        size: 64,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 48),

              Text(
                context.tr('loc_title'),
                style: GoogleFonts.tajawal(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.emeraldDark,
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),

              const SizedBox(height: 12),

              Text(
                context.tr('loc_desc'),
                style: GoogleFonts.tajawal(
                  fontSize: 15,
                  color: AppColors.grey500,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),


              const Spacer(),

              // Allow location button
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _requestLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(AppColors.white),
                          ),
                        )
                      : Text(
                          context.tr('loc_allow_btn'),
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                ),
              ),

              const SizedBox(height: 12),

              // Manual fallback picker button
              SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _selectCityManually,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    foregroundColor: AppColors.emerald,
                  ),
                  child: Text(
                    context.tr('loc_manual_btn'),
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald,
                    ),
                  ),

                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Manual City Picker Bottom Sheet ──────────────────────────────
class _ManualCityPickerSheet extends ConsumerWidget {
  const _ManualCityPickerSheet();

  // Mock Coordinates of Major Arab Cities
  static const List<Map<String, dynamic>> _cities = [
    {'nameKey': 'city_makkah', 'name': 'مكة المكرمة', 'lat': 21.3891, 'lng': 39.8579},
    {'nameKey': 'city_madinah', 'name': 'المدينة المنورة', 'lat': 24.5247, 'lng': 39.5692},
    {'nameKey': 'city_riyadh', 'name': 'الرياض', 'lat': 24.7136, 'lng': 46.6753},
    {'nameKey': 'city_jeddah', 'name': 'جدة', 'lat': 21.5433, 'lng': 39.1728},
    {'nameKey': 'city_dubai', 'name': 'دبي', 'lat': 25.2048, 'lng': 55.2708},
    {'nameKey': 'city_cairo', 'name': 'القاهرة', 'lat': 30.0444, 'lng': 31.2357},
    {'nameKey': 'city_casablanca', 'name': 'الدار البيضاء', 'lat': 33.5731, 'lng': -7.5898},
    {'nameKey': 'city_amman', 'name': 'عمان', 'lat': 31.9454, 'lng': 35.9284},
  ];


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('loc_select_city'),
            style: GoogleFonts.tajawal(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.emeraldDark,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('loc_select_city_desc'),
            style: GoogleFonts.tajawal(
              fontSize: 14,
              color: AppColors.grey500,
            ),
            textDirection: TextDirection.rtl,
          ),

          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _cities.length,
              separatorBuilder: (_, __) => const Divider(color: AppColors.divider),
              itemBuilder: (context, index) {
                final city = _cities[index];
                final nameKey = city['nameKey'] as String;
                final localizedName = context.tr(nameKey);
                return ListTile(
                  title: Text(
                    localizedName,
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  trailing: const Icon(
                    Icons.location_city_rounded,
                    color: AppColors.emerald,
                  ),
                  onTap: () async {
                    final newLoc = UserLocation(
                      latitude: city['lat'] as double,
                      longitude: city['lng'] as double,
                      name: localizedName,
                      isGps: false,
                    );

                    // GoRouter auto-redirects when userLocationProvider
                    // becomes non-null — no explicit context.go needed.
                    await ref.read(userLocationProvider.notifier).setLocation(newLoc);

                    // Optionally update Firestore city for real (non-guest) users.
                    final user = ref.read(firebaseAuthProvider).currentUser;
                    if (user != null && !user.isAnonymous) {
                      try {
                        await ref.read(userRepositoryProvider).updateUserDoc(
                          user.uid,
                          {'city': localizedName},
                        );
                      } catch (e) {
                        debugPrint('Warning: Could not update city in Firestore: $e');
                      }
                    }
                  },
                );

              },
            ),
          ),
        ],
      ),
    );
  }
}
