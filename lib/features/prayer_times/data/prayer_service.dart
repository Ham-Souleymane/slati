import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/location_service.dart';
import '../domain/prayer_times_model.dart';
import 'prayer_method_mapper.dart';

/// Service that fetches prayer times from the Aladhan API and caches them
/// in [SharedPreferences] keyed by `{date}_{lat}_{lng}_{methodId}`.
///
/// Cache invalidation strategy:
///  - Refetch if date has changed (new day).
///  - Refetch if location changed by more than 10 km.
///  - Refetch if method changed.
class PrayerService {
  PrayerService(this._prefs);

  final SharedPreferences _prefs;

  static const String _cacheKey = 'prayer_times_cache';

  // ── Public API ────────────────────────────────────────────────

  /// Fetches prayer times for today. Returns cached data when available and
  /// still valid; otherwise calls the Aladhan API.
  Future<PrayerTimes?> getPrayerTimes({
    required double latitude,
    required double longitude,
    required int methodId,
  }) async {
    final today = _todayString();

    // Try cache first
    final cached = _loadFromCache();
    if (cached != null && _isCacheValid(cached, today, latitude, longitude, methodId)) {
      debugPrint('[PrayerService] Returning cached prayer times for $today');
      return cached;
    }

    // Fetch from API
    return _fetchFromApi(
      latitude: latitude,
      longitude: longitude,
      methodId: methodId,
      date: today,
    );
  }

  /// Reverse-geocodes [latitude]/[longitude] to a country ISO code using the
  /// device's geocoding library. Returns null on failure.
  Future<String?> reverseGeocodeCountryCode(double latitude, double longitude) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        return placemarks.first.isoCountryCode;
      }
    } catch (e) {
      debugPrint('[PrayerService] Reverse-geocode failed: $e');
    }
    return null;
  }

  /// Returns the recommended Aladhan method ID for [countryCode].
  int methodForCountry(String? countryCode) {
    if (countryCode == null) return 3; // MWL fallback
    return PrayerMethodMapper.methodForCountry(countryCode);
  }

  // ── Private helpers ───────────────────────────────────────────

  String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  PrayerTimes? _loadFromCache() {
    try {
      final jsonStr = _prefs.getString(_cacheKey);
      if (jsonStr == null) return null;
      return PrayerTimes.fromJson(
        json.decode(jsonStr) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[PrayerService] Cache read error: $e');
      return null;
    }
  }

  bool _isCacheValid(
    PrayerTimes cached,
    String today,
    double lat,
    double lng,
    int methodId,
  ) {
    if (cached.date != today) return false;
    if (cached.methodId != methodId) return false;

    // Check if location drifted more than 10 km
    final distance = LocationService.calculateDistance(
      startLat: cached.latitude,
      startLng: cached.longitude,
      endLat: lat,
      endLng: lng,
    );
    return distance < 10.0;
  }

  Future<PrayerTimes?> _fetchFromApi({
    required double latitude,
    required double longitude,
    required int methodId,
    required String date,
  }) async {
    // Format date as DD-MM-YYYY for the API
    final parts = date.split('-');
    final apiDate = '${parts[2]}-${parts[1]}-${parts[0]}';

    final uri = Uri.parse(
      'https://api.aladhan.com/v1/timings/$apiDate'
      '?latitude=$latitude&longitude=$longitude&method=$methodId',
    );

    debugPrint('[PrayerService] Fetching: $uri');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[PrayerService] API error ${response.statusCode}: ${response.body}');
        return null;
      }

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      if (decoded['code'] != 200) {
        debugPrint('[PrayerService] API returned non-200 code: ${decoded['status']}');
        return null;
      }

      final timings = decoded['data']['timings'] as Map<String, dynamic>;

      final result = PrayerTimes(
        fajr: _cleanTime(timings['Fajr'] as String),
        sunrise: _cleanTime(timings['Sunrise'] as String),
        dhuhr: _cleanTime(timings['Dhuhr'] as String),
        asr: _cleanTime(timings['Asr'] as String),
        maghrib: _cleanTime(timings['Maghrib'] as String),
        isha: _cleanTime(timings['Isha'] as String),
        date: date,
        methodId: methodId,
        latitude: latitude,
        longitude: longitude,
      );

      // Persist to cache
      await _prefs.setString(_cacheKey, json.encode(result.toJson()));
      debugPrint('[PrayerService] Fetched and cached prayer times for $date');
      return result;
    } catch (e) {
      debugPrint('[PrayerService] Fetch failed: $e');
      return null;
    }
  }

  /// Strips timezone suffix from times like "05:24 (EET)" → "05:24"
  String _cleanTime(String raw) {
    return raw.split(' ').first.trim();
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

/// Provider for the PrayerService, using the app-level SharedPreferences.
final prayerServiceProvider = Provider<PrayerService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PrayerService(prefs);
});

/// Notifier to manage the user-chosen calculation method override (null → auto-detect).
class PrayerMethodOverrideNotifier extends Notifier<int?> {
  @override
  int? build() {
    return null;
  }

  void setMethod(int? methodId) {
    state = methodId;
  }
}

/// Provider for the calculation method override.
final prayerMethodOverrideProvider =
    NotifierProvider<PrayerMethodOverrideNotifier, int?>(
  PrayerMethodOverrideNotifier.new,
);

/// Derives the active calculation method ID from override or country auto-detect.
/// Auto-detect is asynchronous and may be null during loading.
final activePrayerMethodProvider = FutureProvider<int>((ref) async {
  // User's explicit override takes precedence
  final override = ref.watch(prayerMethodOverrideProvider);
  if (override != null) return override;

  // Auto-detect from reverse geocode
  final location = ref.watch(userLocationProvider);
  if (location == null) return 3; // MWL fallback

  final service = ref.watch(prayerServiceProvider);
  final countryCode = await service.reverseGeocodeCountryCode(
    location.latitude,
    location.longitude,
  );
  return service.methodForCountry(countryCode);
});

/// Fetches today's prayer times based on the user's location and the active method.
final prayerTimesProvider = FutureProvider<PrayerTimes?>((ref) async {
  final location = ref.watch(userLocationProvider);
  if (location == null) return null;

  final methodAsync = ref.watch(activePrayerMethodProvider);
  final methodId = methodAsync.asData?.value ?? 3;

  final service = ref.watch(prayerServiceProvider);
  return service.getPrayerTimes(
    latitude: location.latitude,
    longitude: location.longitude,
    methodId: methodId,
  );
});
