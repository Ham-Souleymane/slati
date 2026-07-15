import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/services/notification_service.dart';
import '../../mosques/data/mosque_repository.dart';
import '../../mosques/domain/mosque_prayer_times_model.dart';
import '../data/prayer_service.dart';
import '../domain/prayer_times_model.dart';

enum PrayerMode { location, mosque }

class FullPrayerTimesScreen extends ConsumerStatefulWidget {
  const FullPrayerTimesScreen({super.key});

  @override
  ConsumerState<FullPrayerTimesScreen> createState() =>
      _FullPrayerTimesScreenState();
}

class _FullPrayerTimesScreenState extends ConsumerState<FullPrayerTimesScreen> {
  PrayerMode _selectedMode = PrayerMode.location;
  String? _selectedMosqueId;
  final Map<String, bool> _alerts = {};
  SharedPreferences? _prefs;
  final DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        for (final prayerName in [
          'الفجر',
          'الشروق',
          'الظهر',
          'العصر',
          'المغرب',
          'العشاء'
        ]) {
          _alerts[prayerName] = _prefs?.getBool('alert_$prayerName') ?? false;
        }
      });
    }
  }

  Future<void> _toggleAlert(String prayerName, String timeStr) async {
    final isGuest = ref.read(isGuestProvider);
    if (isGuest) {
      context.showSnackBar(context.tr('guest_upgrade_title'), isError: false);
      return;
    }

    final current = _alerts[prayerName] ?? false;
    final next = !current;

    if (next) {
      await NotificationService.instance
          .schedulePrayerAlert(prayerName, timeStr);
    } else {
      await NotificationService.instance.cancelPrayerAlert(prayerName);
    }

    if (_prefs != null) {
      await _prefs!.setBool('alert_$prayerName', next);
    }
    setState(() {
      _alerts[prayerName] = next;
    });

    if (mounted) {
      final displayName = context.tr(prayerName);
      context.showSnackBar(
        next
            ? context.tr('alert_enabled', args: {'{name}': displayName})
            : context.tr('alert_disabled', args: {'{name}': displayName}),
      );
    }
  }

  String _getHijriDate(BuildContext context) {
    final hijri = HijriCalendar.now();
    final monthKeys = [
      'hijri_muharram', 'hijri_safar', 'hijri_rabi1', 'hijri_rabi2',
      'hijri_jumada1', 'hijri_jumada2', 'hijri_rajab', 'hijri_shaban',
      'hijri_ramadan', 'hijri_shawwal', 'hijri_dhulqada', 'hijri_dhulhijja'
    ];
    final monthName = context.tr(monthKeys[hijri.hMonth - 1]);
    final suffix = context.tr('hijri_suffix');
    return '${hijri.hDay} $monthName ${hijri.hYear} $suffix';
  }

  String _getGregorianDate(BuildContext context) {
    const dayKeys = [
      'day_mon', 'day_tue', 'day_wed', 'day_thu', 'day_fri', 'day_sat', 'day_sun'
    ];
    const monthKeys = [
      'month_jan', 'month_feb', 'month_mar', 'month_apr',
      'month_may', 'month_jun', 'month_jul', 'month_aug',
      'month_sep', 'month_oct', 'month_nov', 'month_dec'
    ];
    final dayName = context.tr(dayKeys[_now.weekday - 1]);
    final monthName = context.tr(monthKeys[_now.month - 1]);
    return '$dayName، ${_now.day} $monthName ${_now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(isGuestProvider);
    final mosquesAsync = ref.watch(mosquesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.emeraldDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('prayer_times_title'),
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
          // ── Date Header ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: AppColors.emeraldDark,
            child: Column(
              children: [
                Text(
                  _getHijriDate(context),
                  style: GoogleFonts.tajawal(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getGregorianDate(context),
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    color: AppColors.emeraldPale,
                  ),
                ),
              ],
            ),
          ),

          // ── Mode Selector Toggle ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _ModeToggleBtn(
                    label: context.tr('by_my_location'),
                    icon: Icons.my_location_rounded,
                    isSelected: _selectedMode == PrayerMode.location,
                    onTap: () => setState(() => _selectedMode = PrayerMode.location),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeToggleBtn(
                    label: context.tr('by_mosque_location'),
                    icon: Icons.mosque_rounded,
                    isSelected: _selectedMode == PrayerMode.mosque,
                    onTap: () => setState(() => _selectedMode = PrayerMode.mosque),
                  ),
                ),
              ],
            ),
          ),

          // ── Mosque Selection Dropdown (Only in Mosque Mode) ──────────
          if (_selectedMode == PrayerMode.mosque)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: mosquesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.emerald),
                ),
                error: (e, _) => Center(
                  child: Text(
                    context.tr('failed_load_saved_mosques'),
                    style: GoogleFonts.tajawal(color: AppColors.error),
                  ),
                ),
                data: (mosques) {
                  if (mosques.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(
                        context.tr('prayer_no_nearby_mosques'),
                        style: GoogleFonts.tajawal(
                          color: AppColors.grey500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  // Default select first if none selected
                  if (_selectedMosqueId == null && mosques.isNotEmpty) {
                    _selectedMosqueId = mosques.first.id;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMosqueId,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded,
                            color: AppColors.emerald),
                        style: GoogleFonts.tajawal(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        items: mosques.map((mosque) {
                          return DropdownMenuItem<String>(
                            value: mosque.id,
                            alignment: Alignment.centerRight,
                            child: Text(
                              mosque.name,
                              textDirection: TextDirection.rtl,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedMosqueId = val);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          // ── Main Content Grid/List ──────────────────────────────────
          Expanded(
            child: _selectedMode == PrayerMode.location
                ? _buildLocationPrayerTimes()
                : _buildMosquePrayerTimes(isGuest),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Location-based prayer times list builder
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildLocationPrayerTimes() {
    final prayerTimesAsync = ref.watch(prayerTimesProvider);

    return prayerTimesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.emerald),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 8),
            Text(
              context.tr('prayer_load_failed'),
              style: GoogleFonts.tajawal(
                  fontSize: 15, color: AppColors.grey700),
            ),
          ],
        ),
      ),
      data: (times) {
        if (times == null) {
          return Center(
            child: Text(
              context.tr('prayer_enable_location'),
              style: GoogleFonts.tajawal(color: AppColors.grey500),
            ),
          );
        }

        final next = times.nextPrayer(_now);

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 80),
          children: [
            ...times.allPrayers.map((entry) {
              final dt = PrayerTimes.timeToDateTime(entry.value, _now);
              final isPast = dt != null && dt.isBefore(_now);
              final isNext = entry.key == next?.key;

              return _PrayerCard(
                name: entry.key,
                time: entry.value,
                isNext: isNext,
                isPast: isPast,
                alertActive: _alerts[entry.key] ?? false,
                onToggleAlert: () => _toggleAlert(entry.key, entry.value),
              );
            }),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Mosque-based prayer times list builder
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMosquePrayerTimes(bool isGuest) {
    if (_selectedMosqueId == null) {
      return Center(
        child: Text(
          context.tr('prayer_select_mosque'),
          style: GoogleFonts.tajawal(color: AppColors.grey500),
        ),
      );
    }

    final mosquePrayerTimesAsync =
        ref.watch(mosqueTodayPrayerTimesProvider(_selectedMosqueId!));

    return mosquePrayerTimesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.emerald),
      ),
      error: (e, _) => Center(
        child: Text(
          context.tr('prayer_mosque_load_failed'),
          style: GoogleFonts.tajawal(color: AppColors.grey700),
        ),
      ),
      data: (times) {
        if (times == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 48, color: AppColors.grey300),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('prayer_no_times_set'),
                    style: GoogleFonts.tajawal(
                        fontSize: 14, color: AppColors.grey700),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final next = times.nextPrayer(_now);

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 80),
          children: [
            ...times.allPrayers.map((entry) {
              final dt = MosquePrayerTimes.timeToDateTime(entry.value, _now);
              final isPast = dt != null && dt.isBefore(_now);
              final isNext = entry.key == next?.key;

              return _PrayerCard(
                name: entry.key,
                time: entry.value,
                isNext: isNext,
                isPast: isPast,
                alertActive: _alerts[entry.key] ?? false,
                onToggleAlert: () => _toggleAlert(entry.key, entry.value),
              );
            }),
            if (times.jumuah != null) ...[
              const SizedBox(height: 12),
              _JumuahSection(time: times.jumuah!),
            ],
            if (times.imamName != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  context.tr('prayer_source', args: {'{name}': times.imamName!}),
                  style: GoogleFonts.tajawal(
                      fontSize: 11, color: AppColors.grey500),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode toggle button helper
// ─────────────────────────────────────────────────────────────────────────────
class _ModeToggleBtn extends StatelessWidget {
  const _ModeToggleBtn({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emerald : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.emerald : AppColors.divider,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.emerald.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.grey700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.tajawal(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.grey700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prayer Row Card
// ─────────────────────────────────────────────────────────────────────────────
class _PrayerCard extends StatelessWidget {
  const _PrayerCard({
    required this.name,
    required this.time,
    required this.isNext,
    required this.isPast,
    required this.alertActive,
    required this.onToggleAlert,
  });

  final String name, time;
  final bool isNext, isPast, alertActive;
  final VoidCallback onToggleAlert;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isNext
            ? AppColors.emeraldDark
            : isPast
                ? AppColors.grey100
                : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext ? AppColors.emeraldMedium : AppColors.divider,
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: AppColors.emeraldDark.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Bell Toggle (on the left)
          IconButton(
            icon: Icon(
              alertActive ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
              color: isNext
                  ? AppColors.gold
                  : alertActive
                      ? AppColors.emerald
                      : AppColors.grey300,
            ),
            onPressed: onToggleAlert,
            tooltip: context.tr('prayer_bell_tooltip'),
          ),
          const Spacer(),
          // Time & Name (RTL layout)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: GoogleFonts.tajawal(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isNext
                      ? AppColors.gold
                      : isPast
                          ? AppColors.grey300
                          : AppColors.charcoal,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                context.tr(name),
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                  color: isNext
                      ? Colors.white
                      : isPast
                          ? AppColors.grey300
                          : AppColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Friday Jumu'ah Card Section
// ─────────────────────────────────────────────────────────────────────────────
class _JumuahSection extends StatelessWidget {
  const _JumuahSection({required this.time});
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.goldPale, Color(0xFFFFF8E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mosque_rounded, color: AppColors.gold, size: 28),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('jumuah_label'),
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: GoogleFonts.tajawal(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
