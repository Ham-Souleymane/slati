import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/prayer_service.dart';
import '../domain/prayer_times_model.dart';

/// Screen that lets users nudge each prayer time earlier or later by ±30 minutes.
/// Offsets are applied client-side without triggering a new API call.
class AdjustPrayerTimesScreen extends ConsumerWidget {
  const AdjustPrayerTimesScreen({super.key});

  static const _prayers = [
    ('الفجر', Icons.brightness_3_rounded),
    ('الشروق', Icons.wb_twilight_rounded),
    ('الظهر', Icons.wb_sunny_rounded),
    ('العصر', Icons.sunny_snowing),
    ('المغرب', Icons.nights_stay_rounded),
    ('العشاء', Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offsets = ref.watch(prayerTuneProvider);
    final tuneNotifier = ref.read(prayerTuneProvider.notifier);
    final hasAny = offsets.values.any((v) => v != 0);
    final prayerTimes = ref.watch(prayerTimesProvider).asData?.value;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.emeraldDark,
        elevation: 0,
        title: Text(
          'ضبط أوقات الصلاة',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (hasAny)
            TextButton(
              onPressed: () async {
                final confirm = await _showResetAllDialog(context);
                if (confirm == true) {
                  await tuneNotifier.resetAll();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم إعادة تعيين جميع التعديلات',
                          style: GoogleFonts.tajawal(),
                        ),
                        backgroundColor: AppColors.emerald,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'إعادة تعيين الكل',
                style: GoogleFonts.tajawal(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Info banner ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.emeraldPale.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.emerald.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.emerald, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'اضبط وقت كل صلاة بدقائق (من -30 إلى +30) لتتوافق مع مسجدك أو تفضيلاتك الشخصية. لا يتطلب ذلك اتصالاً بالإنترنت.',
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      color: AppColors.emeraldDark,
                      height: 1.5,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),

          // ── Prayer offset cards ─────────────────────────────────
          for (final (name, icon) in _prayers)
            _PrayerOffsetCard(
              prayerName: name,
              icon: icon,
              offset: offsets[name] ?? 0,
              timeStr: _getTimeForPrayer(prayerTimes, name),
              onChanged: (val) => tuneNotifier.setOffset(name, val),
              onReset: () => tuneNotifier.resetPrayer(name),
            ),
        ],
      ),
    );
  }

  String _getTimeForPrayer(PrayerTimes? times, String name) {
    if (times == null) return '--:--';
    switch (name) {
      case 'الفجر': return times.fajr;
      case 'الشروق': return times.sunrise;
      case 'الظهر': return times.dhuhr;
      case 'العصر': return times.asr;
      case 'المغرب': return times.maghrib;
      case 'العشاء': return times.isha;
      default: return '--:--';
    }
  }

  Future<bool?> _showResetAllDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'إعادة تعيين الكل',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w800),
          textDirection: TextDirection.rtl,
        ),
        content: Text(
          'هل تريد إزالة جميع تعديلات الأوقات والعودة إلى الأوقات المحسوبة؟',
          style: GoogleFonts.tajawal(fontSize: 14),
          textDirection: TextDirection.rtl,
        ),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('إلغاء', style: GoogleFonts.tajawal()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('إعادة تعيين', style: GoogleFonts.tajawal()),
          ),
        ],
      ),
    );
  }
}

// ── Per-prayer offset card ────────────────────────────────────────────────────

class _PrayerOffsetCard extends StatelessWidget {
  const _PrayerOffsetCard({
    required this.prayerName,
    required this.icon,
    required this.offset,
    required this.timeStr,
    required this.onChanged,
    required this.onReset,
  });

  final String prayerName;
  final IconData icon;
  final int offset;
  final String timeStr;
  final ValueChanged<int> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final isAdjusted = offset != 0;
    final offsetLabel = offset > 0 ? '+$offset دقيقة' : offset < 0 ? '$offset دقيقة' : 'بدون تعديل';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdjusted
              ? AppColors.emerald.withValues(alpha: 0.5)
              : AppColors.divider,
          width: isAdjusted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Header row ──────────────────────────────────────────
          Row(
            children: [
              // Reset button (only when adjusted)
              if (isAdjusted)
                GestureDetector(
                  onTap: onReset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.restart_alt_rounded,
                            size: 14, color: AppColors.error),
                        const SizedBox(width: 3),
                        Text(
                          'إعادة',
                          style: GoogleFonts.tajawal(
                            fontSize: 11,
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const Spacer(),

              // Prayer name + icon
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    prayerName,
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isAdjusted
                          ? AppColors.emerald.withValues(alpha: 0.12)
                          : AppColors.grey100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: isAdjusted ? AppColors.emerald : AppColors.grey500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Offset label ────────────────────────────────────────
          Align(
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Column(
                key: ValueKey('${offset}_$timeStr'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: GoogleFonts.tajawal(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: isAdjusted ? AppColors.emeraldDark : AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    offsetLabel,
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isAdjusted ? AppColors.emerald : AppColors.grey500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Stepper row ─────────────────────────────────────────
          Row(
            children: [
              // Minus button
              _StepButton(
                icon: Icons.remove_rounded,
                enabled: offset > -30,
                onTap: () => onChanged(offset - 1),
                onLongPress: () => onChanged((offset - 5).clamp(-30, 30)),
              ),

              // Slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.emerald,
                    inactiveTrackColor: AppColors.divider,
                    thumbColor: AppColors.emerald,
                    overlayColor: AppColors.emerald.withValues(alpha: 0.12),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 10),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: offset.toDouble(),
                    min: -30,
                    max: 30,
                    divisions: 60,
                    onChanged: (val) => onChanged(val.round()),
                  ),
                ),
              ),

              // Plus button
              _StepButton(
                icon: Icons.add_rounded,
                enabled: offset < 30,
                onTap: () => onChanged(offset + 1),
                onLongPress: () => onChanged((offset + 5).clamp(-30, 30)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Step button helper ────────────────────────────────────────────────────────

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.onLongPress,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? AppColors.emerald : AppColors.grey100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : AppColors.grey300,
          size: 20,
        ),
      ),
    );
  }
}
