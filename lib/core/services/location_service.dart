import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Class representing the user's current selected location.
class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.isGps,
    this.accuracyMeters,     // GPS horizontal accuracy in metres (null = manual)
    this.capturedAtMs,       // epoch ms when this GPS fix was taken
    this.altitudeMeters,     // altitude above sea level in metres (optional)
  });

  final double latitude;
  final double longitude;
  final String name; // e.g. "موقعك الحالي" or manual city name
  final bool isGps;

  /// Horizontal accuracy of the GPS fix in metres.
  /// Null for manually-chosen city locations.
  final double? accuracyMeters;

  /// Unix timestamp (milliseconds) when the GPS fix was captured.
  /// Used to decide when to refresh the cached fix.
  final int? capturedAtMs;

  /// Altitude above sea level in metres.
  final double? altitudeMeters;

  /// Returns true if this GPS fix is fresh enough (< 8 hours old).
  bool get isFresh {
    if (!isGps || capturedAtMs == null) return false;
    final ageMs = DateTime.now().millisecondsSinceEpoch - capturedAtMs!;
    return ageMs < const Duration(hours: 8).inMilliseconds;
  }

  /// Returns true if the GPS fix meets prayer-time precision standards (≤ 1 km accuracy).
  bool get isPrecise => !isGps || (accuracyMeters != null && accuracyMeters! <= 1000.0);

  /// Human-readable accuracy label for debugging / UI.
  String get accuracyLabel {
    if (!isGps || accuracyMeters == null) return '—';
    final m = accuracyMeters!;
    if (m <= 20) return '±${m.round()} م (ممتاز)';
    if (m <= 100) return '±${m.round()} م (جيد جداً)';
    if (m <= 500) return '±${m.round()} م (جيد)';
    if (m <= 1000) return '±${m.round()} م (مقبول)';
    return '±${(m / 1000).toStringAsFixed(1)} كم (تقريبي)';
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'name': name,
        'isGps': isGps,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
        if (capturedAtMs != null) 'capturedAtMs': capturedAtMs,
        if (altitudeMeters != null) 'altitudeMeters': altitudeMeters,
      };

  factory UserLocation.fromJson(Map<String, dynamic> json) => UserLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        name: json['name'] as String,
        isGps: json['isGps'] as bool,
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
        capturedAtMs: (json['capturedAtMs'] as num?)?.toInt(),
        altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble(),
      );

  UserLocation copyWith({
    double? latitude,
    double? longitude,
    String? name,
    bool? isGps,
    double? accuracyMeters,
    int? capturedAtMs,
    double? altitudeMeters,
  }) {
    return UserLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      name: name ?? this.name,
      isGps: isGps ?? this.isGps,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      capturedAtMs: capturedAtMs ?? this.capturedAtMs,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
    );
  }
}

/// Provider for SharedPreferences.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize this provider in main()');
});

/// Notifier to manage the user's active location state.
class UserLocationNotifier extends Notifier<UserLocation?> {
  static const _prefKey = 'user_location_config';

  @override
  UserLocation? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final jsonStr = prefs.getString(_prefKey);
    if (jsonStr != null) {
      try {
        return UserLocation.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Error loading saved location: $e');
      }
    }
    return null;
  }

  Future<void> setLocation(UserLocation location) async {
    state = location;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_prefKey, json.encode(location.toJson()));
  }

  Future<void> clearLocation() async {
    state = null;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_prefKey);
  }
}

/// Provider to watch/update user location reactively.
final userLocationProvider =
    NotifierProvider<UserLocationNotifier, UserLocation?>(UserLocationNotifier.new);

// ── Location Service ──────────────────────────────────────────────────────────

/// Service to check/request permissions and fetch GPS coordinates.
///
/// Uses a two-pass strategy for precision:
///   1. Fast fix with `LocationAccuracy.high` (≤ 10 s) — shown immediately.
///   2. Refinement pass with `LocationAccuracy.bestForNavigation` if the first
///      fix has accuracy > 200 m, waiting up to 8 s more.
class LocationService {
  /// Request location permission. Returns true if granted.
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      final status = await Geolocator.requestPermission();
      return status == LocationPermission.always ||
          status == LocationPermission.whileInUse;
    } else {
      final status = await Permission.locationWhenInUse.request();
      return status.isGranted;
    }
  }

  /// Check permission status. Returns true if granted.
  Future<bool> checkPermission() async {
    if (kIsWeb) {
      final status = await Geolocator.checkPermission();
      return status == LocationPermission.always ||
          status == LocationPermission.whileInUse;
    } else {
      final status = await Permission.locationWhenInUse.status;
      return status.isGranted;
    }
  }

  /// Fetches the best available GPS position using a two-pass strategy.
  ///
  /// Pass 1 — `LocationAccuracy.high` with a 10 s timeout.
  /// Pass 2 — if accuracy > [refinementThresholdM] (default 200 m), we try
  ///           `LocationAccuracy.bestForNavigation` for up to 8 more seconds.
  ///
  /// Falls back to last known position if both passes fail.
  Future<Position?> getCurrentPosition({
    double refinementThresholdM = 200.0,
  }) async {
    final isGranted = await checkPermission();
    if (!isGranted) return null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    Position? best;

    // ── Pass 1: Fast high-accuracy fix ──────────────────────────
    try {
      best = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      debugPrint(
        '[LocationService] Pass 1 fix: '
        'lat=${best.latitude.toStringAsFixed(6)}, '
        'lng=${best.longitude.toStringAsFixed(6)}, '
        'accuracy=${best.accuracy.toStringAsFixed(1)} m',
      );
    } catch (e) {
      debugPrint('[LocationService] Pass 1 failed: $e');
    }

    // ── Pass 2: Refine if accuracy is coarse ─────────────────────
    final needsRefinement =
        best == null || best.accuracy > refinementThresholdM;
    if (needsRefinement) {
      try {
        final refined = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 8),
          ),
        );
        // Only upgrade if the refined fix is genuinely better
        if (best == null || refined.accuracy < best.accuracy) {
          best = refined;
          debugPrint(
            '[LocationService] Pass 2 refined: '
            'accuracy=${best.accuracy.toStringAsFixed(1)} m',
          );
        }
      } catch (e) {
        debugPrint('[LocationService] Pass 2 failed: $e');
      }
    }

    // ── Fallback: last known position ─────────────────────────────
    if (best == null) {
      best = await Geolocator.getLastKnownPosition();
      if (best != null) {
        debugPrint('[LocationService] Using last known position as fallback');
      }
    }

    return best;
  }

  /// Calculates the distance in kilometres between two points using the
  /// Haversine formula.
  static double calculateDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const double earthRadiusKm = 6371.0;

    final double dLat = _degreesToRadians(endLat - startLat);
    final double dLng = _degreesToRadians(endLng - startLng);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(startLat)) *
            cos(_degreesToRadians(endLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}

/// Provider for LocationService.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

