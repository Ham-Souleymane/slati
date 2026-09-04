import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../domain/prayer_times_model.dart';
import 'prayer_method_mapper.dart';

/// Service that fetches prayer times from the Aladhan API and caches them
/// in [SharedPreferences] with full offline support.
class PrayerService {
  PrayerService(this._prefs);

  final SharedPreferences _prefs;

  static const String _cacheKey = 'prayer_times_cache';
  static const String _lastKnownKey = 'last_known_prayer_times';
  static const String _monthCachePrefix = 'prayer_month_';

  // ── Public API ────────────────────────────────────────────────

  /// Fetches prayer times for today. Returns cached data when available and
  /// still valid; otherwise calls the Aladhan API with complete offline fallback.
  Future<PrayerTimes?> getPrayerTimes({
    required double latitude,
    required double longitude,
    required int methodId,
  }) async {
    final today = _todayString();

    // 1. Try today's primary cache
    final cached = _loadFromCache();
    if (cached != null && _isCacheValid(cached, today, latitude, longitude, methodId)) {
      debugPrint('[PrayerService] Returning valid cached prayer times for $today');
      // Fire monthly calendar fetch in background if not yet cached for this month
      _precacheMonthInBackground(
        latitude: latitude,
        longitude: longitude,
        methodId: methodId,
      );
      _syncToNative(cached);
      return cached;
    }

    // 2. Try monthly cache for today's date if primary cache missed
    final monthCached = _loadFromMonthCache(today, latitude, longitude, methodId);
    if (monthCached != null) {
      debugPrint('[PrayerService] Found prayer times for $today in monthly cache');
      await _saveToPrimaryCache(monthCached);
      _syncToNative(monthCached);
      return monthCached;
    }

    // 3. Fetch from Aladhan API
    final fetched = await _fetchFromApi(
      latitude: latitude,
      longitude: longitude,
      methodId: methodId,
      date: today,
    );

    if (fetched != null) {
      // Trigger background monthly cache
      _precacheMonthInBackground(
        latitude: latitude,
        longitude: longitude,
        methodId: methodId,
      );
      _syncToNative(fetched);
      return fetched;
    }

    // 4. Offline Fallback: If network failed (no cnx), return last known cached prayer times
    final fallback = _loadLastKnown();
    if (fallback != null) {
      debugPrint('[PrayerService] Network unavailable: Falling back to last known prayer times');
      final fallbackToday = fallback.copyWith(date: today);
      _syncToNative(fallbackToday);
      return fallbackToday;
    }

    return null;
  }

  void _syncToNative(PrayerTimes times) {
    try {
      NotificationService.instance.syncPrayerAlerts(times, _prefs);
    } catch (e) {
      debugPrint('[PrayerService] Error syncing prayer alerts to native: $e');
    }
  }

  /// Reverse-geocodes [latitude]/[longitude] to a country ISO code using the
  /// device's geocoding library. Returns null on failure.
  Future<String?> reverseGeocodeCountryCode(double latitude, double longitude) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final code = placemarks.first.isoCountryCode;
        if (code != null && code.isNotEmpty) {
          await _prefs.setString('last_known_country_code', code);
          return code;
        }
      }
    } catch (e) {
      debugPrint('[PrayerService] Reverse-geocode failed: $e');
    }
    return _prefs.getString('last_known_country_code');
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

  PrayerTimes? _loadLastKnown() {
    try {
      final jsonStr = _prefs.getString(_lastKnownKey) ?? _prefs.getString(_cacheKey);
      if (jsonStr == null) return null;
      return PrayerTimes.fromJson(
        json.decode(jsonStr) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[PrayerService] Last known read error: $e');
      return null;
    }
  }

  Future<void> _saveToPrimaryCache(PrayerTimes times) async {
    final jsonStr = json.encode(times.toJson());
    await _prefs.setString(_cacheKey, jsonStr);
    await _prefs.setString(_lastKnownKey, jsonStr);
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

  PrayerTimes? _loadFromMonthCache(
    String dateStr,
    double lat,
    double lng,
    int methodId,
  ) {
    try {
      final now = DateTime.now();
      final monthKey = '$_monthCachePrefix${now.year}_${now.month}';
      final jsonStr = _prefs.getString(monthKey);
      if (jsonStr == null) return null;

      final map = json.decode(jsonStr) as Map<String, dynamic>;
      final dayData = map[dateStr];
      if (dayData == null) return null;

      final times = PrayerTimes.fromJson(dayData as Map<String, dynamic>);
      if (_isCacheValid(times, dateStr, lat, lng, methodId)) {
        return times;
      }
    } catch (e) {
      debugPrint('[PrayerService] Error reading month cache: $e');
    }
    return null;
  }

  Future<void> _precacheMonthInBackground({
    required double latitude,
    required double longitude,
    required int methodId,
  }) async {
    final now = DateTime.now();
    final monthKey = '$_monthCachePrefix${now.year}_${now.month}';
    if (_prefs.containsKey(monthKey)) {
      return; // Already cached for current month
    }

    try {
      final uri = Uri.parse(
        'https://api.aladhan.com/v1/calendar/${now.year}/${now.month}'
        '?latitude=$latitude&longitude=$longitude&method=$methodId',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return;

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      if (decoded['code'] != 200 || decoded['data'] is! List) return;

      final dataList = decoded['data'] as List;
      final Map<String, dynamic> monthMap = {};

      for (final dayItem in dataList) {
        if (dayItem is! Map<String, dynamic>) continue;
        final timings = dayItem['timings'] as Map<String, dynamic>?;
        final dateObj = dayItem['date']?['gregorian'] as Map<String, dynamic>?;
        if (timings == null || dateObj == null) continue;

        final dayStr = (dateObj['day'] ?? '').toString().padLeft(2, '0');
        final monthStr = (dateObj['month']?['number'] ?? now.month).toString().padLeft(2, '0');
        final yearStr = (dateObj['year'] ?? now.year).toString().padLeft(4, '0');
        final formattedDate = '$yearStr-$monthStr-$dayStr';

        final pt = PrayerTimes(
          fajr: _cleanTime(timings['Fajr'] as String),
          sunrise: _cleanTime(timings['Sunrise'] as String),
          dhuhr: _cleanTime(timings['Dhuhr'] as String),
          asr: _cleanTime(timings['Asr'] as String),
          maghrib: _cleanTime(timings['Maghrib'] as String),
          isha: _cleanTime(timings['Isha'] as String),
          date: formattedDate,
          methodId: methodId,
          latitude: latitude,
          longitude: longitude,
        );

        monthMap[formattedDate] = pt.toJson();
      }

      if (monthMap.isNotEmpty) {
        await _prefs.setString(monthKey, json.encode(monthMap));
        debugPrint('[PrayerService] Successfully precached ${monthMap.length} days for ${now.year}-${now.month}');
      }
    } catch (e) {
      debugPrint('[PrayerService] Month precache background task failed: $e');
    }
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

      // Persist to primary and fallback cache
      await _saveToPrimaryCache(result);
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
  static const _overrideKey = 'prayer_method_override';

  @override
  int? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt(_overrideKey);
  }

  Future<void> setMethod(int? methodId) async {
    state = methodId;
    final prefs = ref.read(sharedPreferencesProvider);
    if (methodId != null) {
      await prefs.setInt(_overrideKey, methodId);
    } else {
      await prefs.remove(_overrideKey);
    }
  }
}

/// Provider for the calculation method override.
final prayerMethodOverrideProvider =
    NotifierProvider<PrayerMethodOverrideNotifier, int?>(
  PrayerMethodOverrideNotifier.new,
);

/// Derives the active calculation method ID from override or country auto-detect.
/// Preserves offline value in SharedPreferences.
final activePrayerMethodProvider = FutureProvider<int>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  const lastMethodKey = 'last_active_prayer_method';

  // User's explicit override takes precedence
  final override = ref.watch(prayerMethodOverrideProvider);
  if (override != null) {
    await prefs.setInt(lastMethodKey, override);
    return override;
  }

  // Auto-detect from reverse geocode
  final location = ref.watch(userLocationProvider);
  if (location == null) {
    return prefs.getInt(lastMethodKey) ?? 3; // Fallback to last known or MWL
  }

  final service = ref.watch(prayerServiceProvider);
  final countryCode = await service.reverseGeocodeCountryCode(
    location.latitude,
    location.longitude,
  );
  final calculatedMethod = service.methodForCountry(countryCode);
  await prefs.setInt(lastMethodKey, calculatedMethod);
  return calculatedMethod;
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

/// Reverse-geocodes user's coordinates to obtain their current city/locality name.
/// Caches the city name locally for offline use.
final userCityProvider = FutureProvider<String?>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  const cityKey = 'last_known_city_name';
  final location = ref.watch(userLocationProvider);
  if (location == null) return prefs.getString(cityKey);

  // If manual location (not GPS), use its name directly
  if (!location.isGps && location.name.isNotEmpty && location.name != 'موقعك الحالي') {
    await prefs.setString(cityKey, location.name);
    return location.name;
  }

  try {
    final placemarks = await geo.placemarkFromCoordinates(
      location.latitude,
      location.longitude,
    );
    if (placemarks.isNotEmpty) {
      final place = placemarks.first;
      for (final val in [
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
        place.country,
      ]) {
        if (val != null && val.trim().isNotEmpty) {
          final cityName = val.trim();
          await prefs.setString(cityKey, cityName);
          return cityName;
        }
      }
    }
  } catch (e) {
    debugPrint('[PrayerService] userCityProvider error: $e');
  }

  // Return last known cached city name if geocoding fails offline
  return prefs.getString(cityKey) ?? location.name;
});
