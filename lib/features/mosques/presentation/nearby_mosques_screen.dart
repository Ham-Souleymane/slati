import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../data/mosque_repository.dart';
import '../domain/mosque_model.dart';

class NearbyMosquesScreen extends ConsumerStatefulWidget {
  const NearbyMosquesScreen({super.key});

  @override
  ConsumerState<NearbyMosquesScreen> createState() =>
      _NearbyMosquesScreenState();
}

class _NearbyMosquesScreenState extends ConsumerState<NearbyMosquesScreen>
    with TickerProviderStateMixin {
  // HCI State: List vs Map view
  bool _isMapView = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final MapController _mapController = MapController();
  late final PageController _pageController;

  // Selected mosque index for map sync
  int _selectedMosqueIndex = 0;

  // Radius filter in km
  double _radiusLimit = 15.0;
  static const List<double> _quickRadii = [5.0, 10.0, 15.0, 25.0, 50.0];

  // User location pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Map follow-mode: when true the map camera tracks the user's GPS position
  bool _followMode = true;
  StreamSubscription<Position>? _locationSubscription;

  // Live GPS position used only for the map camera + user-dot marker.
  // We keep this separate from userLocationProvider to avoid rebuilding
  // the entire screen (mosque list re-sort) on every movement tick.
  LatLng? _livePosition;

  // Throttle how often we push updates into the global Riverpod notifier
  // (which triggers mosque distance recalculation).
  DateTime _lastGlobalUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? _lastGlobalUpdatePos;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Seed mock data if empty using user's location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userLoc = ref.read(userLocationProvider);
      if (userLoc != null) {
        ref
            .read(mosqueRepositoryProvider)
            .seedMockMosquesIfEmpty(userLoc.latitude, userLoc.longitude);
      }
    });

    // Subscribe to live GPS updates and pan the map when follow-mode is on
    _startLocationStream();
  }

  void _startLocationStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // fire every ≥5 m so the dot feels smooth
    );
    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) {
        final newPos = LatLng(position.latitude, position.longitude);

        // 1. Move the map camera immediately — no setState, no rebuild.
        if (_followMode && _isMapView) {
          _mapController.move(newPos, _mapController.camera.zoom);
        }

        // 2. Update the animated user-dot marker (lightweight setState).
        if (mounted) {
          setState(() => _livePosition = newPos);
        }

        // 3. Push to the global notifier (triggers mosque-list recalc) only
        //    when the user has moved ≥100 m OR 30 s have elapsed.
        //    This prevents jank from rebuilding the entire screen while walking.
        final now = DateTime.now();
        final sinceLastUpdate = now.difference(_lastGlobalUpdate).inSeconds;
        final distanceMoved = _lastGlobalUpdatePos == null
            ? double.infinity
            : LocationService.calculateDistance(
                startLat: _lastGlobalUpdatePos!.latitude,
                startLng: _lastGlobalUpdatePos!.longitude,
                endLat: position.latitude,
                endLng: position.longitude,
              ) * 1000; // convert km → m

        if (sinceLastUpdate >= 30 || distanceMoved >= 100) {
          _lastGlobalUpdate = now;
          _lastGlobalUpdatePos = newPos;
          ref.read(userLocationProvider.notifier).setLocation(
                UserLocation(
                  latitude: position.latitude,
                  longitude: position.longitude,
                  name: ref.read(userLocationProvider)?.name ?? 'موقعك الحالي',
                  isGps: true,
                ),
              );
        }
      },
      onError: (e) {
        debugPrint('[NearbyMosquesScreen] Location stream error: $e');
      },
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _searchController.dispose();
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleFollow(MosqueModel mosque) async {
    final isGuest = ref.read(isGuestProvider);
    if (isGuest) {
      context.showGuestUpgradeSheet();
      return;
    }
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;
    final repo = ref.read(mosqueRepositoryProvider);
    final isFollowing =
        ref.read(isFollowingProvider(mosque.id)).asData?.value ?? false;
    if (isFollowing) {
      await repo.unfollowMosque(uid, mosque.id);
      if (mounted) {
        context.showSnackBar(
            context.tr('unfollowed_mosque', args: {'{name}': mosque.name}));
      }
    } else {
      await repo.followMosque(uid, mosque);
      if (mounted) {
        context.showSnackBar(context
            .tr('followed_mosque_success', args: {'{name}': mosque.name}));
      }
    }
  }

  Future<void> _openDirections(MosqueModel mosque) async {
    final lat = mosque.geopoint.latitude;
    final lng = mosque.geopoint.longitude;
    final name = Uri.encodeComponent(mosque.name);

    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final appleMapsUrl = 'https://maps.apple.com/?q=$name&ll=$lat,$lng';

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl),
            mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        await launchUrl(Uri.parse(appleMapsUrl),
            mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('maps_launch_failed'))),
        );
      }
    }
  }

  Map<String, String> _getNextPrayerInfo() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour < 5) return {'name': 'الفجر', 'time': '04:30 ص'};
    if (hour < 12) return {'name': 'الظهر', 'time': '12:20 م'};
    if (hour < 15) return {'name': 'العصر', 'time': '03:45 م'};
    if (hour < 18) return {'name': 'المغرب', 'time': '07:10 م'};
    if (hour < 20) return {'name': 'العشاء', 'time': '08:40 م'};
    return {'name': 'الفجر', 'time': '04:30 ص'};
  }

  void _onMosqueSelected(
      int index, List<Map<String, dynamic>> processedMosques,
      {bool showDetailsModal = false}) {
    if (index < 0 || index >= processedMosques.length) return;
    setState(() => _selectedMosqueIndex = index);

    final mosque = processedMosques[index]['model'] as MosqueModel;
    final distance = processedMosques[index]['distance'] as double;

    _mapController.move(
      LatLng(mosque.geopoint.latitude, mosque.geopoint.longitude),
      15.5,
    );

    if (_pageController.hasClients &&
        _pageController.page?.round() != index) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }

    if (showDetailsModal) {
      _showMosqueDetailsSheet(mosque, distance);
    }
  }

  // ── Show Mosque Details Modal with Big "Go to" (Directions) Button ──
  void _showMosqueDetailsSheet(MosqueModel mosque, double distance) {
    final nextPrayer = _getNextPrayerInfo();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mosque Top Header: Photo + Name + Verified Badge + Distance
            Row(
              textDirection: TextDirection.rtl,
              children: [
                // Mosque Avatar
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: mosque.photo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(mosque.photo!, fit: BoxFit.cover),
                        )
                      : const Center(
                          child: Icon(
                            Icons.mosque_rounded,
                            color: AppColors.emerald,
                            size: 34,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                // Titles
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            child: Text(
                              mosque.name,
                              style: GoogleFonts.tajawal(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emeraldDark,
                              ),
                              textDirection: TextDirection.rtl,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (mosque.verified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded,
                                color: AppColors.gold, size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          const Icon(Icons.location_on_rounded,
                              color: AppColors.gold, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'يبعد ${distance.toStringAsFixed(1)} كم عن موقعك',
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mosque.address,
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          color: AppColors.grey500,
                        ),
                        textDirection: TextDirection.rtl,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 14),

            // Quick Info Badges: Status & Next Prayer & Capacity
            Row(
              textDirection: TextDirection.rtl,
              children: [
                // Open status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.emerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'مفتوح الآن',
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Next Prayer badge
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      'الصلاة القادمة: ${context.tr(nextPrayer['name'] ?? '')} (${nextPrayer['time']})',
                      style: GoogleFonts.tajawal(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                      textDirection: TextDirection.rtl,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Primary Action: Big "Go to Mosque" (الانتقال إلى المسجد) ──
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _openDirections(mosque);
              },
              icon: const Icon(Icons.navigation_rounded, size: 20),
              label: Text(
                'الانتقال إلى المسجد (Go to Mosque)',
                style: GoogleFonts.tajawal(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                elevation: 3,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Secondary Actions: Details + Follow ──
            Row(
              children: [
                // Mosque Page Details button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/mosque/${mosque.id}');
                    },
                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                    label: Text(
                      'تفاصيل المسجد',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.emeraldDark,
                      side: const BorderSide(color: AppColors.emerald, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Follow / Save button
                Consumer(
                  builder: (context, ref, _) {
                    final isFollowingAsync =
                        ref.watch(isFollowingProvider(mosque.id));
                    final isFollowing =
                        isFollowingAsync.asData?.value ?? false;
                    return GestureDetector(
                      onTap: () => _toggleFollow(mosque),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isFollowing
                              ? AppColors.emerald
                              : AppColors.cream,
                          border: Border.all(
                            color: isFollowing
                                ? AppColors.emerald
                                : AppColors.divider,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFollowing
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: isFollowing
                                  ? Colors.white
                                  : AppColors.grey700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isFollowing ? 'متابع' : 'متابعة',
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isFollowing
                                    ? Colors.white
                                    : AppColors.grey700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userLoc = ref.watch(userLocationProvider);
    final mosquesAsync = ref.watch(mosquesStreamProvider);

    if (userLoc == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      );
    }

    final userLatLng = LatLng(userLoc.latitude, userLoc.longitude);

    return Scaffold(
      backgroundColor: AppColors.cream,
      extendBody: true,
      floatingActionButtonLocation: const _RightFloatingActionButtonLocation(),
      floatingActionButton: Material(
        color: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: () {
            final isGuest = ref.read(isGuestProvider);
            if (isGuest) {
              context.showGuestUpgradeSheet();
              return;
            }
            context.push('/add-mosque');
          },
          borderRadius: BorderRadius.circular(30),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF004D2E), Color(0xFF00331F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('add_mosque_fab'),
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.add_location_alt_rounded,
                  color: AppColors.goldLight,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.emeraldDark,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('nearby_mosques_title'),
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: Colors.white,
          ),
        ),
      ),
      body: mosquesAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (err, _) => Center(
            child: Text('${context.tr('load_error_prefix')}$err',
                style: GoogleFonts.tajawal(color: AppColors.grey700))),
        data: (mosques) {
          // Calculate distance & sort strictly ascending (Nearest first)
          final List<Map<String, dynamic>> processedMosques = [];

          for (final mosque in mosques) {
            final distance = LocationService.calculateDistance(
              startLat: userLoc.latitude,
              startLng: userLoc.longitude,
              endLat: mosque.geopoint.latitude,
              endLng: mosque.geopoint.longitude,
            );

            final matchesRadius = distance <= _radiusLimit;
            final matchesQuery = mosque.name
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                mosque.address
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());

            if (matchesRadius && matchesQuery) {
              processedMosques.add({
                'model': mosque,
                'distance': distance,
              });
            }
          }

          // Sort strictly by distance (closest first: 0.1km, 0.4km, etc.)
          processedMosques.sort((a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double));

          return Column(
            children: [
              // ── HCI Top Control Bar: Search + Segmented Toggle + Radius ──
              _buildInteractiveHeader(processedMosques.length),

              // ── Content View (List View OR Interactive Map View) ─────────
              Expanded(
                child: _isMapView
                    ? _buildMapView(processedMosques, userLatLng)
                    : _buildListView(processedMosques),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HCI Header: Segmented Switch + Search Bar + Quick Radius Chips
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildInteractiveHeader(int count) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // 1. Prominent Segmented Switch (List View vs Map View)
          Container(
            height: 46,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF2F7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                // List View Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_isMapView) setState(() => _isMapView = false);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: !_isMapView ? AppColors.emerald : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: !_isMapView
                            ? [
                                BoxShadow(
                                  color: AppColors.emerald.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.view_list_rounded,
                            size: 20,
                            color: !_isMapView ? Colors.white : AppColors.grey700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'قائمة المساجد',
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color:
                                  !_isMapView ? Colors.white : AppColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Map View Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!_isMapView) setState(() => _isMapView = true);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: _isMapView ? AppColors.emerald : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _isMapView
                            ? [
                                BoxShadow(
                                  color: AppColors.emerald.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_rounded,
                            size: 20,
                            color: _isMapView ? Colors.white : AppColors.grey700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'عرض الخريطة',
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _isMapView ? Colors.white : AppColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2. Search Field
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.charcoal),
              decoration: InputDecoration(
                hintText: 'ابحث عن اسم المسجد أو الحي...',
                hintStyle: GoogleFonts.tajawal(
                    color: AppColors.grey500, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.emerald, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppColors.grey500, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. Quick Radius Chips & Count Feedback
          Row(
            children: [
              Text(
                'النطاق:',
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickRadii.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final r = _quickRadii[i];
                      final isSelected = (_radiusLimit - r).abs() < 0.1;
                      return ChoiceChip(
                        label: Text('${r.toInt()} كم'),
                        selected: isSelected,
                        selectedColor: AppColors.emerald,
                        backgroundColor: AppColors.cream,
                        labelStyle: GoogleFonts.tajawal(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.grey700,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.emerald
                                : AppColors.divider,
                          ),
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _radiusLimit = r);
                        },
                      );
                    },
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count مسجد',
                  style: GoogleFonts.tajawal(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HCI Map View: Interactive Markers + Recenter/Zoom + Mosque Bottom Carousel
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMapView(
      List<Map<String, dynamic>> processedMosques, LatLng userLatLng) {

    final markers = <Marker>[
      // 1. Animated Radar User Location Marker
      // Uses _livePosition for smooth real-time movement; falls back to
      // userLatLng (from the Riverpod provider) before the stream fires.
      Marker(
        point: _livePosition ?? userLatLng,
        width: 70,
        height: 70,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 32 * _pulseAnimation.value,
                  height: 32 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2563EB)
                        .withValues(alpha: max(0.0, 0.45 - (_pulseAnimation.value - 0.8) * 0.4)),
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ];

    // 2. High-Affordance Interactive Mosque Markers
    for (var i = 0; i < processedMosques.length; i++) {
      final item = processedMosques[i];
      final MosqueModel mosque = item['model'] as MosqueModel;
      final distance = item['distance'] as double;
      final isSelected = i == _selectedMosqueIndex;
      final latLng =
          LatLng(mosque.geopoint.latitude, mosque.geopoint.longitude);

      markers.add(
        Marker(
          point: latLng,
          width: isSelected ? 130 : 95,
          height: isSelected ? 75 : 60,
          child: GestureDetector(
            onTap: () => _onMosqueSelected(i, processedMosques, showDetailsModal: true),
            child: AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge with Mosque Name & Distance
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.emeraldDark
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.gold
                            : AppColors.emerald.withValues(alpha: 0.6),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mosque_rounded,
                          size: 14,
                          color: isSelected ? AppColors.gold : AppColors.emerald,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${distance.toStringAsFixed(1)} كم',
                            style: GoogleFonts.tajawal(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.emeraldDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Pin point
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 22,
                    color: isSelected
                        ? AppColors.emeraldDark
                        : AppColors.emerald,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        // ── Map Canvas ──
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: userLatLng,
            initialZoom: 14.5,
            minZoom: 3.0,
            maxZoom: 18.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            // Disable follow-mode whenever the user manually pans/zooms
            onPositionChanged: (position, hasGesture) {
              if (hasGesture && _followMode) {
                setState(() => _followMode = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.slatk.slatkapp',
              maxZoom: 19,
            ),
            MarkerLayer(markers: markers),
          ],
        ),

        // ── Floating Action Tools on Map: Recenter & Zoom ──
        Positioned(
          top: 16,
          left: 16,
          child: Column(
            children: [
              // Recenter to User Location
              _buildMapToolButton(
                icon: Icons.my_location_rounded,
                tooltip: 'موقعي الحالي',
                color: _followMode ? const Color(0xFF2563EB) : AppColors.grey700,
                onTap: () {
                  setState(() => _followMode = true);
                  _mapController.move(userLatLng, 15.0);
                },
              ),
              const SizedBox(height: 8),
              // Zoom in
              _buildMapToolButton(
                icon: Icons.add_rounded,
                tooltip: 'تكبير',
                onTap: () {
                  final zoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, zoom + 1);
                },
              ),
              const SizedBox(height: 4),
              // Zoom out
              _buildMapToolButton(
                icon: Icons.remove_rounded,
                tooltip: 'تصغير',
                onTap: () {
                  final zoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, zoom - 1);
                },
              ),
            ],
          ),
        ),

        // ── Bottom Horizontal Carousel of Closest Mosques ──
        if (processedMosques.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 95,
            child: SizedBox(
              height: 160,
              child: PageView.builder(
                controller: _pageController,
                itemCount: processedMosques.length,
                onPageChanged: (index) {
                  _onMosqueSelected(index, processedMosques);
                },
                itemBuilder: (context, index) {
                  final item = processedMosques[index];
                  final MosqueModel mosque = item['model'] as MosqueModel;
                  final distance = item['distance'] as double;
                  final isSelected = index == _selectedMosqueIndex;

                  return GestureDetector(
                    onTap: () => _showMosqueDetailsSheet(mosque, distance),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.emerald
                              : AppColors.divider,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isSelected ? 0.15 : 0.08),
                            blurRadius: isSelected ? 14 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            // Mosque Avatar / Icon
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: AppColors.cream,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: mosque.photo != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.network(mosque.photo!,
                                          fit: BoxFit.cover),
                                    )
                                  : const Center(
                                      child: Icon(
                                        Icons.mosque_rounded,
                                        color: AppColors.emerald,
                                        size: 34,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    textDirection: TextDirection.rtl,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          mosque.name,
                                          style: GoogleFonts.tajawal(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.emeraldDark,
                                          ),
                                          textDirection: TextDirection.rtl,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              AppColors.gold.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '#${index + 1} الأقرب',
                                          style: GoogleFonts.tajawal(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.gold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${distance.toStringAsFixed(1)} كم من موقعك • ${mosque.address}',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 11,
                                      color: AppColors.grey500,
                                    ),
                                    textDirection: TextDirection.rtl,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  // Action buttons: "Go to (الانتقال)" and "Details (التفاصيل)"
                                  Row(
                                    textDirection: TextDirection.rtl,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => _openDirections(mosque),
                                        icon: const Icon(Icons.navigation_rounded,
                                            size: 14),
                                        label: Text(
                                          'الانتقال (Go to)',
                                          style: GoogleFonts.tajawal(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.emerald,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 7),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _showMosqueDetailsSheet(mosque, distance),
                                        icon: const Icon(
                                            Icons.info_outline_rounded,
                                            size: 14),
                                        label: Text(
                                          'التفاصيل',
                                          style: GoogleFonts.tajawal(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.emeraldDark,
                                          side: const BorderSide(
                                              color: AppColors.emerald),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 7),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        else
          Positioned(
            left: 20,
            right: 20,
            bottom: 110,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_searching_rounded,
                      color: AppColors.emerald,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'لا توجد مساجد في هذا النطاق حالياً',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.emeraldDark,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'جرّب زيادة النطاق أو اضغط "أضف مسجداً"',
                          style: GoogleFonts.tajawal(
                            fontSize: 11,
                            color: AppColors.grey500,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMapToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = AppColors.charcoal,
  }) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HCI List View: Sorted by Distance (Closest First with Badges)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildListView(List<Map<String, dynamic>> mosques) {
    if (mosques.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_rounded,
                size: 64, color: AppColors.grey300),
            const SizedBox(height: 16),
            Text(
              context.tr('no_mosques_found'),
              style: GoogleFonts.tajawal(fontSize: 16, color: AppColors.grey500),
            ),
          ],
        ),
      );
    }

    final nextPrayer = _getNextPrayerInfo();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: mosques.length,
      itemBuilder: (context, index) {
        final item = mosques[index];
        final MosqueModel mosque = item['model'] as MosqueModel;
        final distance = item['distance'] as double;
        final isTopClosest = index == 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isTopClosest
                  ? AppColors.emerald.withValues(alpha: 0.6)
                  : AppColors.divider,
              width: isTopClosest ? 1.5 : 1.0,
            ),
          ),
          elevation: isTopClosest ? 3 : 0,
          shadowColor: isTopClosest
              ? AppColors.emerald.withValues(alpha: 0.15)
              : Colors.transparent,
          child: InkWell(
            onTap: () => _showMosqueDetailsSheet(mosque, distance),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    textDirection: TextDirection.rtl,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mosque Image Placeholder
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: mosque.photo != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(mosque.photo!,
                                    fit: BoxFit.cover),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.mosque_rounded,
                                  color: AppColors.emerald,
                                  size: 38,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                Expanded(
                                  child: Text(
                                    mosque.name,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.emeraldDark,
                                    ),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isTopClosest
                                        ? AppColors.emerald
                                        : AppColors.gold
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isTopClosest
                                        ? 'الأقرب إليك'
                                        : '#${index + 1}',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isTopClosest
                                          ? Colors.white
                                          : AppColors.gold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${context.tr('distance')} ${distance.toStringAsFixed(1)} ${context.tr('km')} • ${mosque.address}',
                              style: GoogleFonts.tajawal(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold,
                              ),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // Status & Next Prayer row
                            Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    context.tr('open'),
                                    style: GoogleFonts.tajawal(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.emerald,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${context.tr('next_prayer')}: ${context.tr(nextPrayer['name'] ?? '')} (${nextPrayer['time']})',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 11,
                                      color: AppColors.grey500,
                                    ),
                                    textDirection: TextDirection.rtl,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Action Buttons Row: Follow + Directions (Go to)
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      // Follow button (reactive)
                      Expanded(
                        child: Consumer(
                          builder: (ctx, ref, _) {
                            final isFollowingAsync = ref
                                .watch(isFollowingProvider(mosque.id));
                            final isFollowing =
                                isFollowingAsync.asData?.value ?? false;
                            return GestureDetector(
                              onTap: () => _toggleFollow(mosque),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isFollowing
                                      ? AppColors.emerald
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isFollowing
                                        ? AppColors.emerald
                                        : AppColors.divider,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isFollowing
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 14,
                                      color: isFollowing
                                          ? Colors.white
                                          : AppColors.grey500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isFollowing
                                          ? context.tr('following')
                                          : context.tr('follow'),
                                      style: GoogleFonts.tajawal(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isFollowing
                                          ? Colors.white
                                          : AppColors.grey500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Directions (Go to) button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openDirections(mosque),
                          icon: const Icon(Icons.navigation_rounded,
                              size: 16),
                          label: Text(
                            'الانتقال (Go to)',
                            style: GoogleFonts.tajawal(
                                fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: AppColors.white,
                            backgroundColor: AppColors.emerald,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom FAB location that always anchors to the bottom-right of the screen
class _RightFloatingActionButtonLocation extends FloatingActionButtonLocation {
  const _RightFloatingActionButtonLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.floatingActionButtonSize.width -
        16.0;
    final double contentBottom = scaffoldGeometry.contentBottom;
    final double fabHeight = scaffoldGeometry.floatingActionButtonSize.height;
    final double fabY = contentBottom - fabHeight - 100.0;
    return Offset(fabX, fabY);
  }
}
