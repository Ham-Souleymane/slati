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
  });

  final double latitude;
  final double longitude;
  final String name; // e.g. "موقعك الحالي" or manual city name
  final bool isGps;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'name': name,
        'isGps': isGps,
      };

  factory UserLocation.fromJson(Map<String, dynamic> json) => UserLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        name: json['name'] as String,
        isGps: json['isGps'] as bool,
      );
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

/// Location Service to check/request permissions and fetch GPS.
class LocationService {
  /// Request location permission using permission_handler.
  Future<PermissionStatus> requestPermission() async {
    return Permission.locationWhenInUse.request();
  }

  /// Check permission status.
  Future<PermissionStatus> checkPermission() async {
    return Permission.locationWhenInUse.status;
  }

  /// Fetch coordinates using Geolocator if permissions are granted.
  Future<Position?> getCurrentPosition() async {
    final status = await checkPermission();
    if (!status.isGranted) return null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Geolocator error: $e');
      // Try last known position if active retrieval times out/fails
      return await Geolocator.getLastKnownPosition();
    }
  }

  /// Calculates the distance in kilometers between two points using the Haversine formula.
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
