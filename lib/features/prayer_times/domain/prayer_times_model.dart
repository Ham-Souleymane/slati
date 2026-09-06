/// Domain model representing the five prayer times for a single day.
class PrayerTimes {
  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
    required this.methodId,
    required this.latitude,
    required this.longitude,
  });

  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  /// The Gregorian date this data corresponds to, in 'yyyy-MM-dd' format.
  final String date;

  /// The Aladhan calculation method ID used for fetching these times.
  final int methodId;

  /// Coordinates used when fetching (for cache-busting on location change).
  final double latitude;
  final double longitude;

  // ── Serialization ─────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'fajr': fajr,
        'sunrise': sunrise,
        'dhuhr': dhuhr,
        'asr': asr,
        'maghrib': maghrib,
        'isha': isha,
        'date': date,
        'methodId': methodId,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory PrayerTimes.fromJson(Map<String, dynamic> json) => PrayerTimes(
        fajr: json['fajr'] as String,
        sunrise: json['sunrise'] as String,
        dhuhr: json['dhuhr'] as String,
        asr: json['asr'] as String,
        maghrib: json['maghrib'] as String,
        isha: json['isha'] as String,
        date: json['date'] as String,
        methodId: (json['methodId'] as num).toInt(),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  PrayerTimes copyWith({
    String? fajr,
    String? sunrise,
    String? dhuhr,
    String? asr,
    String? maghrib,
    String? isha,
    String? date,
    int? methodId,
    double? latitude,
    double? longitude,
  }) {
    return PrayerTimes(
      fajr: fajr ?? this.fajr,
      sunrise: sunrise ?? this.sunrise,
      dhuhr: dhuhr ?? this.dhuhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
      date: date ?? this.date,
      methodId: methodId ?? this.methodId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  // ── Derived helpers ───────────────────────────────────────────

  /// Returns all five main prayer name→time pairs in order.
  List<MapEntry<String, String>> get allPrayers => [
        MapEntry('الفجر', fajr),
        MapEntry('الشروق', sunrise),
        MapEntry('الظهر', dhuhr),
        MapEntry('العصر', asr),
        MapEntry('المغرب', maghrib),
        MapEntry('العشاء', isha),
      ];

  /// Computes the [DateTime] for a time string such as "05:24", "٠٥:٢٤", or "04:30 م" relative to [reference].
  /// Correctly handles Arabic/Persian numerals, AM/PM markers, and 12-to-24 hour conversion for afternoon prayers.
  static DateTime? timeToDateTime(String timeStr, DateTime reference, [String? prayerName]) {
    try {
      final clean = timeStr
          .replaceAll('\u200e', '')
          .replaceAll('\u200f', '')
          .replaceAll('\u061c', '')
          .replaceAll('\u00a0', ' ')
          .trim();
      final isPM = clean.contains('م') || clean.toUpperCase().contains('PM');
      final isAM = clean.contains('ص') || clean.toUpperCase().contains('AM');

      // Normalize Arabic (٠-٩) and Persian (۰-۹) digits to Latin (0-9)
      final normalized = clean.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (m) {
        final code = m.group(0)!.codeUnitAt(0);
        if (code >= 0x0660 && code <= 0x0669) {
          return String.fromCharCode(code - 0x0660 + 0x30);
        } else if (code >= 0x06F0 && code <= 0x06F9) {
          return String.fromCharCode(code - 0x06F0 + 0x30);
        }
        return m.group(0)!;
      });

      final match = RegExp(r'(\d{1,2})\s*:\s*(\d{1,2})').firstMatch(normalized);
      if (match == null) return null;

      var hour = int.tryParse(match.group(1)!);
      final minute = int.tryParse(match.group(2)!);
      if (hour == null || minute == null) return null;

      if (isPM && hour < 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      } else if (!isPM && !isAM && prayerName != null) {
        // Auto-detect 12-hour values for afternoon/night prayers if given without AM/PM
        if (prayerName.contains('ظهر') && hour >= 1 && hour <= 10) hour += 12;
        if (prayerName.contains('عصر') && hour < 12) hour += 12;
        if (prayerName.contains('مغرب') && hour < 12) hour += 12;
        if (prayerName.contains('عشاء') && hour < 12) hour += 12;
      }

      return DateTime(reference.year, reference.month, reference.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  /// Returns the name and time of the next prayer relative to [now].
  /// Returns null if all prayers have passed for the day.
  MapEntry<String, String>? nextPrayer(DateTime now) {
    // We skip sunrise in "next prayer" since it's not a salah
    final salawat = [
      MapEntry('الفجر', fajr),
      MapEntry('الظهر', dhuhr),
      MapEntry('العصر', asr),
      MapEntry('المغرب', maghrib),
      MapEntry('العشاء', isha),
    ];

    for (final entry in salawat) {
      final dt = timeToDateTime(entry.value, now, entry.key);
      if (dt != null && dt.isAfter(now)) return entry;
    }
    return null; // all prayers have passed today — return tomorrow's Fajr conceptually
  }

  /// Returns the number of [Duration] remaining until the next prayer.
  /// If today's prayers have all completed, accurately returns the time until tomorrow's Fajr.
  Duration? timeUntilNextPrayer(DateTime now) {
    final next = nextPrayer(now);
    if (next != null) {
      final dt = timeToDateTime(next.value, now, next.key);
      if (dt != null) {
        final diff = dt.difference(now);
        return diff.isNegative ? Duration.zero : diff;
      }
    }
    // All prayers completed today -> time until tomorrow's Fajr
    final tomorrowFajr = timeToDateTime(fajr, now.add(const Duration(days: 1)), 'الفجر');
    if (tomorrowFajr != null) {
      final diff = tomorrowFajr.difference(now);
      return diff.isNegative ? Duration.zero : diff;
    }
    return null;
  }

  /// Returns the exact [DateTime] of the upcoming prayer (today's next or tomorrow's Fajr).
  DateTime? nextPrayerDateTime(DateTime now) {
    final next = nextPrayer(now);
    if (next != null) {
      return timeToDateTime(next.value, now, next.key);
    }
    return timeToDateTime(fajr, now.add(const Duration(days: 1)), 'الفجر');
  }
}
