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

  /// Computes the [DateTime] for a time string such as "05:24" relative to [now].
  static DateTime? timeToDateTime(String timeStr, DateTime reference) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(reference.year, reference.month, reference.day, hour, minute);
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
      final dt = timeToDateTime(entry.value, now);
      if (dt != null && dt.isAfter(now)) return entry;
    }
    return null; // all prayers have passed — return tomorrow's Fajr conceptually
  }

  /// Returns the number of [Duration] remaining until the next prayer.
  Duration? timeUntilNextPrayer(DateTime now) {
    final next = nextPrayer(now);
    if (next == null) return null;
    final dt = timeToDateTime(next.value, now);
    if (dt == null) return null;
    return dt.difference(now);
  }
}
