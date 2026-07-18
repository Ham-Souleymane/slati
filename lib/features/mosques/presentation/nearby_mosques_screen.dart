import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';


import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/extensions.dart';
import '../data/mosque_repository.dart';
import '../domain/mosque_model.dart';

class NearbyMosquesScreen extends ConsumerStatefulWidget {
  const NearbyMosquesScreen({super.key});

  @override
  ConsumerState<NearbyMosquesScreen> createState() => _NearbyMosquesScreenState();
}

class _NearbyMosquesScreenState extends ConsumerState<NearbyMosquesScreen> {
  bool _isMapView = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final MapController _mapController = MapController();
  
  // Radius filter in km
  double _radiusLimit = 15.0;

  @override
  void initState() {
    super.initState();
    // Seed mock data if empty using user's location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userLoc = ref.read(userLocationProvider);
      if (userLoc != null) {
        ref
            .read(mosqueRepositoryProvider)
            .seedMockMosquesIfEmpty(userLoc.latitude, userLoc.longitude);
      }
    });
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
        if (mounted) context.showSnackBar(context.tr('unfollowed_mosque', args: {'{name}': mosque.name}));
      } else {
        await repo.followMosque(uid, mosque);
        if (mounted) context.showSnackBar(context.tr('followed_mosque_success', args: {'{name}': mosque.name}));
      }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Native Map Launcher ──────────────────────────────────────
  Future<void> _openDirections(MosqueModel mosque) async {
    final lat = mosque.geopoint.latitude;
    final lng = mosque.geopoint.longitude;
    final name = Uri.encodeComponent(mosque.name);
    
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final appleMapsUrl = 'https://maps.apple.com/?q=$name&ll=$lat,$lng';

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
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

  // ── Next Prayer Mock Helper ──────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    final userLoc = ref.watch(userLocationProvider);
    final mosquesAsync = ref.watch(mosquesStreamProvider);

    if (userLoc == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userLatLng = LatLng(userLoc.latitude, userLoc.longitude);

    return Scaffold(
      backgroundColor: AppColors.cream,
      extendBody: true,
      appBar: AppBar(
        title: Text(
          context.tr('nearby_mosques_title'),
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          // Toggle between Map and List View
          IconButton(
            icon: Icon(
              _isMapView ? Icons.view_list_rounded : Icons.map_rounded,
              color: AppColors.emerald,
            ),
            onPressed: () => setState(() => _isMapView = !_isMapView),
            tooltip: _isMapView ? context.tr('list_view') : context.tr('map_view'),
          ),
        ],
      ),
      body: mosquesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('${context.tr('load_error_prefix')}$err')),
        data: (mosques) {
          // 1. Calculate distances & filter/sort
          final List<Map<String, dynamic>> processedMosques = [];

          for (final mosque in mosques) {
            final distance = LocationService.calculateDistance(
              startLat: userLoc.latitude,
              startLng: userLoc.longitude,
              endLat: mosque.geopoint.latitude,
              endLng: mosque.geopoint.longitude,
            );

            // Filter by radius & search query
            final matchesRadius = distance <= _radiusLimit;
            final matchesQuery = mosque.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                mosque.address.toLowerCase().contains(_searchQuery.toLowerCase());

            if (matchesRadius && matchesQuery) {
              processedMosques.add({
                'model': mosque,
                'distance': distance,
              });
            }
          }

          // Sort by distance (ascending)
          processedMosques.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

          return Column(
            children: [
              // Top filter & Search area
              _buildTopBar(),

              // Content View
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

  // ── Top Search & Radius Bar ─────────────────────────────────
  Widget _buildTopBar() {
    final isEn = context.tr('km') == 'km';
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Search TextField
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: context.tr('search_mosque'),
              hintStyle: GoogleFonts.tajawal(color: AppColors.grey500),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.emerald),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: AppColors.grey500),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          const SizedBox(height: 10),
          // Radius Slider Row
          Row(
            children: [
              Text(
                context.tr('radius_limit_label'),
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _radiusLimit,
                  min: 1.0,
                  max: 50.0,
                  divisions: 49,
                  activeColor: AppColors.emerald,
                  inactiveColor: AppColors.divider,
                  label: '${_radiusLimit.round()} ${context.tr('km')}',
                  onChanged: (val) => setState(() => _radiusLimit = val),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_radiusLimit.round()} ${context.tr('km')}',
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emerald,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Map View ────────────────────────────────────────────────
  Widget _buildMapView(List<Map<String, dynamic>> mosques, LatLng userLatLng) {
    // Generate markers
    final markers = <Marker>[
      // User current position marker
      Marker(
        point: userLatLng,
        width: 60,
        height: 60,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.emerald.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 2),
          ),
          child: const Center(
            child: Icon(
              Icons.my_location_rounded,
              color: Colors.blue,
              size: 24,
            ),
          ),
        ),
      ),
    ];

    // Mosque markers
    for (final item in mosques) {
      final MosqueModel mosque = item['model'] as MosqueModel;
      final distance = item['distance'] as double;
      final latLng = LatLng(mosque.geopoint.latitude, mosque.geopoint.longitude);

      markers.add(
        Marker(
          point: latLng,
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _showMosqueMiniCard(mosque, distance),
            child: const Icon(
              Icons.location_pin,
              color: AppColors.gold,
              size: 40,
            ),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: userLatLng,
        initialZoom: 14.5,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.slatk.slatkapp',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  // ── Show Mosque Mini Card on Marker Tap ─────────────────────
  void _showMosqueMiniCard(MosqueModel mosque, double distance) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MosqueMiniCard(
        mosque: mosque,
        distance: distance,
        onDirections: () => _openDirections(mosque),
        onFollow: () => _toggleFollow(mosque),
        onDetails: () {
          Navigator.pop(context);
          context.push('/mosque/${mosque.id}');
        },
      ),
    );
  }

  // ── List View ───────────────────────────────────────────────
  Widget _buildListView(List<Map<String, dynamic>> mosques) {
    if (mosques.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_rounded, size: 64, color: AppColors.grey300),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: mosques.length,
      itemBuilder: (context, index) {
        final item = mosques[index];
        final MosqueModel mosque = item['model'] as MosqueModel;
        final distance = item['distance'] as double;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.divider),
          ),
          elevation: 0,
          child: InkWell(
            onTap: () => context.push('/mosque/${mosque.id}'),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                textDirection: TextDirection.rtl,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Mosque Image Placeholder
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: mosque.photo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(mosque.photo!, fit: BoxFit.cover),
                        )
                      : const Center(
                          child: Icon(
                            Icons.mosque_rounded,
                            color: AppColors.emerald,
                            size: 40,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        mosque.name,
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraldDark,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${context.tr('distance')} ${distance.toStringAsFixed(1)} ${context.tr('km')}',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Status & Next Prayer row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.1),
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
                          Text(
                            '${context.tr('next_prayer')}: ${context.tr(nextPrayer['name'] ?? '')} (${nextPrayer['time']})',
                            style: GoogleFonts.tajawal(
                              fontSize: 11,
                              color: AppColors.grey500,
                            ),
                          ),
                        ],
                      ),
      const SizedBox(height: 12),
                      // Action Buttons Row: Follow + Directions
                      Row(
                        children: [
                          // Follow button (reactive)
                          Expanded(
                            child: Consumer(
                              builder: (ctx, ref, _) {
                                final isFollowingAsync =
                                    ref.watch(isFollowingProvider(mosque.id));
                                final isFollowing =
                                    isFollowingAsync.asData?.value ?? false;
                                return GestureDetector(
                                  onTap: () => _toggleFollow(mosque),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
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
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
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
                                          isFollowing ? context.tr('following') : context.tr('follow'),
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
                          // Directions button
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => _openDirections(mosque),
                              icon: const Icon(Icons.directions_rounded,
                                  size: 16),
                              label: Text(
                                context.tr('directions'),
                                style: GoogleFonts.tajawal(
                                    fontWeight: FontWeight.w700),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.white,
                                backgroundColor: AppColors.emerald,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
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
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────────
// Map Mini Card widget (extracted for ConsumerWidget access)
// ────────────────────────────────────────────────────────────────────────────────

class _MosqueMiniCard extends ConsumerWidget {
  const _MosqueMiniCard({
    required this.mosque,
    required this.distance,
    required this.onDirections,
    required this.onFollow,
    required this.onDetails,
  });

  final MosqueModel mosque;
  final double distance;
  final VoidCallback onDirections;
  final VoidCallback onFollow;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowingAsync = ref.watch(isFollowingProvider(mosque.id));
    final isFollowing = isFollowingAsync.asData?.value ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          Text(
            mosque.address,
            style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.grey500),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 4),
          Text(
            '${context.tr('distance')} ${distance.toStringAsFixed(1)} ${context.tr('km')}',
            style: GoogleFonts.tajawal(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.gold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Follow button
              Expanded(
                child: GestureDetector(
                  onTap: onFollow,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
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
                          size: 16,
                          color:
                              isFollowing ? Colors.white : AppColors.grey500,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isFollowing ? context.tr('following') : context.tr('follow'),
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isFollowing ? Colors.white : AppColors.grey500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Directions button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions_rounded, size: 16),
                  label: Text(context.tr('directions'),
                      style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Details button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.info_outline_rounded, size: 16),
                  label: Text(context.tr('details'),
                      style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.emeraldDark,
                    side: const BorderSide(color: AppColors.emerald),
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
    );
  }
}
