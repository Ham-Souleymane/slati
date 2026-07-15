import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the official prayer times for a specific mosque on a specific date.
/// Written by the Imam app; may include imam overrides on top of the Aladhan base.
class MosquePrayerTimes {
  const MosquePrayerTimes({
    required this.mosqueId,
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.jumuah,
    this.imamName,
    this.methodId,
  });

  final String mosqueId;

  /// Gregorian date string 'yyyy-MM-dd'
  final String date;

  // ── Standard prayers ─────────────────────────────────────────
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  /// Optional Jumu'ah (Friday prayer) time — only set by the Imam app.
  final String? jumuah;

  /// Display name of the imam who last updated times, for attribution.
  final String? imamName;

  /// Aladhan method ID used as the base for these times.
  final int? methodId;

  // ── Firestore deserialization ─────────────────────────────────

  factory MosquePrayerTimes.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String mosqueId,
  ) {
    final data = doc.data() ?? {};
    return MosquePrayerTimes(
      mosqueId: mosqueId,
      date: doc.id, // document ID is the date string
      fajr: data['fajr'] as String? ?? '--:--',
      sunrise: data['sunrise'] as String? ?? '--:--',
      dhuhr: data['dhuhr'] as String? ?? '--:--',
      asr: data['asr'] as String? ?? '--:--',
      maghrib: data['maghrib'] as String? ?? '--:--',
      isha: data['isha'] as String? ?? '--:--',
      jumuah: data['jumuah'] as String?,
      imamName: data['imamName'] as String?,
      methodId: data['methodId'] as int?,
    );
  }

  // ── Derived helpers ───────────────────────────────────────────

  List<MapEntry<String, String>> get allPrayers => [
        MapEntry('الفجر', fajr),
        MapEntry('الشروق', sunrise),
        MapEntry('الظهر', dhuhr),
        MapEntry('العصر', asr),
        MapEntry('المغرب', maghrib),
        MapEntry('العشاء', isha),
      ];

  static DateTime? timeToDateTime(String timeStr, DateTime reference) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(reference.year, reference.month, reference.day, hour, minute);
  }

  MapEntry<String, String>? nextPrayer(DateTime now) {
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
    return null;
  }
}
