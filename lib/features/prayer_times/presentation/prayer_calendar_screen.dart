import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../data/prayer_service.dart';

// ── Monthly calendar data model ───────────────────────────────────────────────

/// Holds parsed prayer times for a single day in the monthly calendar.
class _DayEntry {
  const _DayEntry({
    required this.gregorianDay,
    required this.hijriDay,
    required this.hijriMonth,
    required this.hijriYear,
    required this.weekday, // 1=Mon … 7=Sun (DateTime.weekday convention)
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  final int gregorianDay;
  final int hijriDay;
  final String hijriMonth; // localised month name
  final int hijriYear;
  final int weekday;
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Fetches the monthly Aladhan calendar for the given [year]/[month].
/// When [methodId] is null the `method` param is omitted from the Aladhan API
/// call so the API auto-selects the correct method for the user's coordinates
/// (same behaviour as the daily prayer times provider).
/// Caches the raw JSON in SharedPreferences under the key
/// `prayer_month_raw_<year>_<month>_auto_<school>` (auto) or
/// `prayer_month_raw_<year>_<month>_<methodId>_<school>` (explicit).
final _monthlyCalendarProvider =
    FutureProvider.family<List<_DayEntry>, (int, int, int?, int)>(
  (ref, params) async {
    final (year, month, methodId, school) = params;
    final location = ref.watch(userLocationProvider);
    if (location == null) return [];

    // Use 'auto' in the cache key when no explicit method is selected so that
    // changing location correctly busts the cache.
    final methodKey = methodId != null ? '$methodId' : 'auto';
    final cacheKey = 'prayer_month_raw_${year}_${month}_${methodKey}_$school';
    final prefs = ref.watch(sharedPreferencesProvider);
    final latAdjOverride = ref.watch(latitudeAdjMethodOverrideProvider);

    // --- Try SharedPreferences cache first ---
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      try {
        final list = json.decode(cached) as List<dynamic>;
        return _parseDayEntries(list);
      } catch (_) {
        // Corrupted cache — fall through to API
      }
    }

    // --- Fetch from Aladhan API ---
    final queryParams = <String, String>{
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      // Omit 'method' when null — Aladhan auto-detects the correct official
      // method from the coordinates (same behaviour as daily prayer provider).
      if (methodId != null) 'method': methodId.toString(),
      'school': school.toString(),
    };
    final resolvedLatAdj = latAdjOverride ??
        (location.latitude.abs() > 48 ? 3 : null);
    if (resolvedLatAdj != null) {
      queryParams['latitudeAdjustmentMethod'] = resolvedLatAdj.toString();
    }

    final uri = Uri.https(
      'api.aladhan.com',
      '/v1/calendar/$year/$month',
      queryParams,
    );

    try {
      final response =
          await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      if (decoded['code'] != 200 || decoded['data'] is! List) {
        throw Exception('API error: ${decoded["status"]}');
      }
      final dataList = decoded['data'] as List<dynamic>;

      // Persist raw list to cache
      await prefs.setString(cacheKey, json.encode(dataList));

      return _parseDayEntries(dataList);
    } catch (e) {
      debugPrint('[PrayerCalendar] Fetch failed: $e');
      rethrow;
    }
  },
);

/// Parses a list of raw Aladhan day objects into [_DayEntry] items.
List<_DayEntry> _parseDayEntries(List<dynamic> dataList) {
  final entries = <_DayEntry>[];
  for (final item in dataList) {
    if (item is! Map<String, dynamic>) continue;
    final timings = item['timings'] as Map<String, dynamic>?;
    final dateObj = item['date'] as Map<String, dynamic>?;
    final gregObj = dateObj?['gregorian'] as Map<String, dynamic>?;
    final hijriObj = dateObj?['hijri'] as Map<String, dynamic>?;
    if (timings == null || gregObj == null || hijriObj == null) continue;

    final gregDay = int.tryParse(gregObj['day'].toString()) ?? 1;
    final gregDateStr = gregObj['date'] as String? ?? '01-01-2025';
    // Format: "DD-MM-YYYY"
    final parts = gregDateStr.split('-');
    int weekday = 1;
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]) ?? 1;
      final m = int.tryParse(parts[1]) ?? 1;
      final y = int.tryParse(parts[2]) ?? 2025;
      weekday = DateTime(y, m, d).weekday;
    }

    final hijriDay = int.tryParse(hijriObj['day'].toString()) ?? 1;
    final hijriMonthObj = hijriObj['month'] as Map<String, dynamic>?;
    final hijriMonthAr = hijriMonthObj?['ar'] as String? ?? '';
    final hijriYear = int.tryParse(hijriObj['year'].toString()) ?? 1446;

    String clean(String raw) => raw.split(' ').first.trim();

    entries.add(_DayEntry(
      gregorianDay: gregDay,
      hijriDay: hijriDay,
      hijriMonth: hijriMonthAr,
      hijriYear: hijriYear,
      weekday: weekday,
      fajr: clean(timings['Fajr'] as String? ?? '--:--'),
      sunrise: clean(timings['Sunrise'] as String? ?? '--:--'),
      dhuhr: clean(timings['Dhuhr'] as String? ?? '--:--'),
      asr: clean(timings['Asr'] as String? ?? '--:--'),
      maghrib: clean(timings['Maghrib'] as String? ?? '--:--'),
      isha: clean(timings['Isha'] as String? ?? '--:--'),
    ));
  }
  return entries;
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Full-screen monthly prayer times calendar.
/// Navigated to from FullPrayerTimesScreen via a calendar icon in the app bar.
class PrayerCalendarScreen extends ConsumerStatefulWidget {
  const PrayerCalendarScreen({super.key});

  @override
  ConsumerState<PrayerCalendarScreen> createState() =>
      _PrayerCalendarScreenState();
}

class _PrayerCalendarScreenState
    extends ConsumerState<PrayerCalendarScreen> {
  late int _year;
  late int _month;

  // Index of the tapped day (0-based into the month's day list), or null = none
  int? _expandedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _prevMonth() {
    setState(() {
      _expandedDay = null;
      if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      _expandedDay = null;
      if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
    });
  }

  String _monthName(int month) {
    const names = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    // Read the user's explicit method override (null = auto-detect by API).
    // Pass null to the provider so the Aladhan calendar endpoint also omits
    // the method param and auto-selects the correct regional method.
    final methodOverride = ref.watch(prayerMethodOverrideProvider);
    final schoolAsync = ref.watch(activePrayerSchoolProvider);
    final school = schoolAsync.asData?.value ?? 0;

    // When no override exists pass null → API auto-detects.
    // When override exists pass it explicitly.
    final calendarAsync = ref.watch(
      _monthlyCalendarProvider((_year, _month, methodOverride, school)),
    );

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.emeraldDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isAr ? 'التقويم الشهري' : 'Monthly Calendar',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Month Navigator ──────────────────────────────────────
          Container(
            color: AppColors.emeraldDark,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded,
                      color: AppColors.gold, size: 28),
                  onPressed: _prevMonth,
                ),
                Text(
                  '${_monthName(_month)} $_year',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.gold, size: 28),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────────
          Expanded(
            child: calendarAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.emerald),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 52, color: AppColors.grey300),
                      const SizedBox(height: 12),
                      Text(
                        isAr
                            ? 'تعذّر تحميل التقويم\nتحقق من اتصالك بالإنترنت'
                            : 'Failed to load calendar\nCheck your internet connection',
                        style: GoogleFonts.tajawal(
                          color: AppColors.grey700,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          context.tr('retry'),
                          style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.w700),
                        ),
                        onPressed: () => ref.invalidate(
                          _monthlyCalendarProvider(
                              (_year, _month, methodOverride, school)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (days) {
                if (days.isEmpty) {
                  return Center(
                    child: Text(
                      isAr
                          ? 'لا توجد بيانات لهذا الشهر'
                          : 'No data for this month',
                      style: GoogleFonts.tajawal(color: AppColors.grey500),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    8,
                    12,
                    MediaQuery.of(context).padding.bottom + 80,
                  ),
                  itemCount: days.length,
                  itemBuilder: (ctx, index) {
                    final day = days[index];
                    final isToday = _year == today.year &&
                        _month == today.month &&
                        day.gregorianDay == today.day;
                    final isExpanded = _expandedDay == index;

                    return _CalendarDayCard(
                      day: day,
                      isToday: isToday,
                      isExpanded: isExpanded,
                      isAr: isAr,
                      onTap: () => setState(() {
                        _expandedDay = isExpanded ? null : index;
                      }),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day Card Widget ───────────────────────────────────────────────────────────

class _CalendarDayCard extends StatelessWidget {
  const _CalendarDayCard({
    required this.day,
    required this.isToday,
    required this.isExpanded,
    required this.isAr,
    required this.onTap,
  });

  final _DayEntry day;
  final bool isToday;
  final bool isExpanded;
  final bool isAr;
  final VoidCallback onTap;

  static const _weekdayAr = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const _weekdayEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _weekdayName() => isAr
      ? _weekdayAr[day.weekday - 1]
      : _weekdayEn[day.weekday - 1];

  bool get _isFriday => day.weekday == 5;

  @override
  Widget build(BuildContext context) {
    final bool isPast = !isToday &&
        DateTime.now().isAfter(DateTime(
          DateTime.now().year,
          DateTime.now().month,
          day.gregorianDay,
          23,
          59,
        ));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isToday
              ? AppColors.emeraldDark
              : _isFriday
                  ? const Color(0xFFFFFBEB) // warm yellow tint for Friday
                  : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isToday
                ? AppColors.emeraldMedium
                : _isFriday
                    ? AppColors.gold.withValues(alpha: 0.5)
                    : AppColors.divider,
          ),
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: AppColors.emeraldDark.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: Column(
          children: [
            // ── Header row ────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Day number circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.gold.withValues(alpha: 0.25)
                          : _isFriday
                              ? AppColors.goldPale
                              : AppColors.cream,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.gregorianDay}',
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isToday
                                ? AppColors.gold
                                : _isFriday
                                    ? AppColors.gold
                                    : AppColors.charcoal,
                          ),
                        ),
                        Text(
                          '${day.hijriDay}',
                          style: GoogleFonts.tajawal(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isToday
                                ? AppColors.goldLight
                                : AppColors.grey500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Day name + Hijri date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _weekdayName(),
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isToday
                                    ? Colors.white
                                    : _isFriday
                                        ? AppColors.gold
                                        : AppColors.charcoal,
                              ),
                            ),
                            if (_isFriday) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? AppColors.gold.withValues(alpha: 0.25)
                                      : AppColors.goldPale,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isAr ? 'الجمعة 🕌' : 'Jumu\'ah 🕌',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${day.hijriDay} ${day.hijriMonth} ${day.hijriYear} هـ',
                          style: GoogleFonts.tajawal(
                            fontSize: 11,
                            color: isToday
                                ? AppColors.emeraldPale
                                : AppColors.grey500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Compact Fajr–Maghrib preview
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _MiniTime(
                        icon: Icons.brightness_3_rounded,
                        time: day.fajr,
                        isToday: isToday,
                        dim: isPast,
                      ),
                      const SizedBox(height: 2),
                      _MiniTime(
                        icon: Icons.wb_sunny_rounded,
                        time: day.maghrib,
                        isToday: isToday,
                        dim: isPast,
                      ),
                    ],
                  ),

                  // Expand chevron
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isToday ? AppColors.gold : AppColors.grey300,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // ── Expanded detail ──────────────────────────────
            if (isExpanded)
              Container(
                decoration: BoxDecoration(
                  color: isToday
                      ? AppColors.emerald.withValues(alpha: 0.5)
                      : AppColors.cream,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(14)),
                ),
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  children: [
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 8),
                    _ExpandedPrayerRow(
                        icon: Icons.brightness_3_rounded,
                        name: isAr ? 'الفجر' : 'Fajr',
                        time: day.fajr,
                        isToday: isToday),
                    _ExpandedPrayerRow(
                        icon: Icons.wb_twilight_rounded,
                        name: isAr ? 'الشروق' : 'Sunrise',
                        time: day.sunrise,
                        isToday: isToday),
                    _ExpandedPrayerRow(
                        icon: Icons.wb_sunny_rounded,
                        name: isAr ? 'الظهر' : 'Dhuhr',
                        time: day.dhuhr,
                        isToday: isToday),
                    _ExpandedPrayerRow(
                        icon: Icons.sunny_snowing,
                        name: isAr ? 'العصر' : 'Asr',
                        time: day.asr,
                        isToday: isToday),
                    _ExpandedPrayerRow(
                        icon: Icons.nights_stay_rounded,
                        name: isAr ? 'المغرب' : 'Maghrib',
                        time: day.maghrib,
                        isToday: isToday),
                    _ExpandedPrayerRow(
                        icon: Icons.dark_mode_rounded,
                        name: isAr ? 'العشاء' : 'Isha',
                        time: day.isha,
                        isToday: isToday),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Helper sub-widgets ────────────────────────────────────────────────────────

class _MiniTime extends StatelessWidget {
  const _MiniTime({
    required this.icon,
    required this.time,
    required this.isToday,
    required this.dim,
  });
  final IconData icon;
  final String time;
  final bool isToday;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final color = isToday
        ? AppColors.gold
        : dim
            ? AppColors.grey300
            : AppColors.grey700;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          time,
          style: GoogleFonts.tajawal(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ExpandedPrayerRow extends StatelessWidget {
  const _ExpandedPrayerRow({
    required this.icon,
    required this.name,
    required this.time,
    required this.isToday,
  });
  final IconData icon;
  final String name;
  final String time;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final textColor = isToday ? Colors.white : AppColors.charcoal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color:
                  isToday ? AppColors.gold : AppColors.emerald),
          const SizedBox(width: 10),
          Text(
            name,
            style: GoogleFonts.tajawal(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const Spacer(),
          Text(
            time,
            style: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isToday ? AppColors.gold : AppColors.emeraldMedium,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
