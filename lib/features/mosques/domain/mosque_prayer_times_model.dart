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

  MapEntry<String, String>? nextPrayer(DateTime now) {
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
    return null;
  }
}
