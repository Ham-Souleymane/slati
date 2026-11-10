import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/prayer_service.dart';

// ── Live countdown provider ───────────────────────────────────────────────────

/// Ticks every second and returns the current [DateTime].
/// Used by the countdown banner to re-render the remaining time.
final _clockProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now())
      .asBroadcastStream();
});

// ── Public widget ─────────────────────────────────────────────────────────────

/// A compact banner that shows:
///  • the name of the next upcoming prayer
///  • a live HH:MM:SS countdown to it
///  • the scheduled time of that prayer
///
/// Integrates with the existing [prayerTimesProvider] and refreshes every second.
class PrayerCountdownBanner extends ConsumerWidget {
  const PrayerCountdownBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the current time (ticks every second)
    final clockAsync = ref.watch(_clockProvider);
    final now = clockAsync.asData?.value ?? DateTime.now();

    // Watch prayer times (cached, does not re-fetch every second)
    final prayerAsync = ref.watch(prayerTimesProvider);

    return prayerAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (times) {
        if (times == null) return const SizedBox.shrink();

        final next = times.nextPrayer(now);
        final duration = times.timeUntilNextPrayer(now);

        if (duration == null) return const SizedBox.shrink();

        // Prayer name: either the next salah today, or tomorrow's Fajr
        final nextName = next?.key ?? 'الفجر';
        final nextTime = next?.value ?? times.fajr;

        final isAr = Localizations.localeOf(context).languageCode == 'ar';

        return _CountdownBannerContent(
          prayerName: _localise(nextName, context),
          prayerTime: nextTime,
          duration: duration,
          isAr: isAr,
          isAfterAllPrayers: next == null,
        );
      },
    );
  }

  String _localise(String arabicName, BuildContext context) {
    // Use app's tr() to resolve to the locale's prayer name
    return context.tr(arabicName);
  }
}

// ── Internal stateless banner ─────────────────────────────────────────────────

class _CountdownBannerContent extends StatelessWidget {
  const _CountdownBannerContent({
    required this.prayerName,
    required this.prayerTime,
    required this.duration,
    required this.isAr,
    required this.isAfterAllPrayers,
  });

  final String prayerName;
  final String prayerTime;
  final Duration duration;
  final bool isAr;
  final bool isAfterAllPrayers;

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // Colour pulse: green when > 15 min, amber when 5–15 min, red when < 5 min
    final minutes = duration.inMinutes;
    final accentColor = minutes >= 15
        ? AppColors.emerald
        : minutes >= 5
            ? AppColors.warning
            : const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        // Subtle gradient mirroring the emerald palette
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.12),
            accentColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Left: hourglass + label ──────────────────────────────
          Icon(
            isAfterAllPrayers
                ? Icons.nightlight_round
                : Icons.hourglass_bottom_rounded,
            color: accentColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAfterAllPrayers
                      ? (isAr
                          ? 'حتى فجر الغد'
                          : 'Until tomorrow\'s Fajr')
                      : (isAr
                          ? 'حتى صلاة $prayerName'
                          : 'Until $prayerName'),
                  style: GoogleFonts.tajawal(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey700,
                  ),
                ),
                const SizedBox(height: 1),
                // Live countdown HH:MM:SS
                Text(
                  _format(duration),
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: 1.5,
                    // Use tabular figures for non-jumping countdown
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          // ── Right: scheduled time ────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isAr ? 'موعد الصلاة' : 'Prayer at',
                style: GoogleFonts.tajawal(
                  fontSize: 10,
                  color: AppColors.grey500,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  prayerTime,
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

