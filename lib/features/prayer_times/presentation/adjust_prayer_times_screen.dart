import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/prayer_method_mapper.dart';
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

    final activeMethodAsync = ref.watch(activePrayerMethodProvider);
    final activeMethodId = activeMethodAsync.asData?.value ?? 3;
    final overrideMethodId = ref.watch(prayerMethodOverrideProvider);

    final activeSchoolAsync = ref.watch(activePrayerSchoolProvider);
    final activeSchoolId = activeSchoolAsync.asData?.value ?? 0;

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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ── Section 1: Calculation method & Asr School ───────────
          _buildSectionHeader('طريقة الحساب والمذهب الفقهي', Icons.settings_suggest_rounded),
          const SizedBox(height: 10),

          // Method Selector Card
          _MethodSelectorCard(
            currentMethodId: activeMethodId,
            isAuto: overrideMethodId == null,
            onTap: () => _showMethodPickerSheet(context, ref, activeMethodId, overrideMethodId),
          ),
          const SizedBox(height: 10),

          // Asr School Selector Card
          _AsrSchoolCard(
            currentSchoolId: activeSchoolId,
            onSchoolChanged: (school) async {
              await ref.read(prayerSchoolOverrideProvider.notifier).setSchool(school);
            },
          ),

          const SizedBox(height: 24),

          // ── Section 2: Minute Tune Offsets ───────────────────────
          _buildSectionHeader('التعديل اليدوي للدقائق', Icons.tune_rounded),
          const SizedBox(height: 8),

          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
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
                    'اضبط وقت كل صلاة بدقائق (من -30 إلى +30) لتتوافق مع مسجدك أو تفضيلاتك الشخصية.',
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.emeraldDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.tajawal(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.emeraldDark,
          ),
        ),
      ],
    );
  }

  void _showMethodPickerSheet(
    BuildContext context,
    WidgetRef ref,
    int currentActiveMethodId,
    int? currentOverrideMethodId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _MethodPickerSheet(
        currentActiveMethodId: currentActiveMethodId,
        currentOverrideMethodId: currentOverrideMethodId,
        onSelect: (selectedMethodId) async {
          Navigator.of(ctx).pop();
          await ref.read(prayerMethodOverrideProvider.notifier).setMethod(selectedMethodId);
        },
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

// ── Calculation Method Selector Card ──────────────────────────────────────────

class _MethodSelectorCard extends StatelessWidget {
  const _MethodSelectorCard({
    required this.currentMethodId,
    required this.isAuto,
    required this.onTap,
  });

  final int currentMethodId;
  final bool isAuto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final methodName = PrayerMethodMapper.labelForMethod(currentMethodId);

    // When auto, show "تلقائي — <method name>" so the user knows which method
    // the API resolved for their location without having to open the picker.
    final badgeText = isAuto ? 'تلقائي' : 'مخصص';
    final subtitleText = isAuto
        ? 'تلقائي — $methodName'
        : methodName;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: AppColors.grey500),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isAuto
                    ? AppColors.emeraldPale.withValues(alpha: 0.6)
                    : AppColors.goldPale,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.tajawal(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isAuto ? AppColors.emeraldDark : AppColors.gold,
                ),
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'طريقة حساب المواقيت',
                  style: GoogleFonts.tajawal(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isAuto ? AppColors.emerald : AppColors.gold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.emeraldPale.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calculate_rounded,
                  color: AppColors.emerald, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Asr School Card ───────────────────────────────────────────────────────────

class _AsrSchoolCard extends StatelessWidget {
  const _AsrSchoolCard({
    required this.currentSchoolId,
    required this.onSchoolChanged,
  });

  final int currentSchoolId;
  final ValueChanged<int> onSchoolChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'مذهب حساب صلاة العصر',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  Text(
                    'يحدد وقت دخول صلاة العصر (طول ظل الشاخص)',
                    style: GoogleFonts.tajawal(
                      fontSize: 11,
                      color: AppColors.grey500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.goldPale,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.balance_rounded,
                    color: AppColors.gold, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Hanafi
              Expanded(
                child: _SchoolOption(
                  title: 'المذهب الحنفي',
                  subtitle: 'ظل الشيء مثليه',
                  isSelected: currentSchoolId == 1,
                  onTap: () => onSchoolChanged(1),
                ),
              ),
              const SizedBox(width: 10),
              // Shafi'i / Maliki / Hanbali
              Expanded(
                child: _SchoolOption(
                  title: 'جمهور الفقهاء',
                  subtitle: 'شافعي، مالكي، حنبلي',
                  isSelected: currentSchoolId == 0,
                  onTap: () => onSchoolChanged(0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SchoolOption extends StatelessWidget {
  const _SchoolOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emerald : AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.emerald : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.tajawal(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.charcoal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.tajawal(
                fontSize: 10,
                color: isSelected ? AppColors.emeraldPale : AppColors.grey500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Method Picker Bottom Sheet ────────────────────────────────────────────────

class _MethodPickerSheet extends StatefulWidget {
  const _MethodPickerSheet({
    required this.currentActiveMethodId,
    required this.currentOverrideMethodId,
    required this.onSelect,
  });

  final int currentActiveMethodId;
  final int? currentOverrideMethodId;
  final ValueChanged<int?> onSelect;

  @override
  State<_MethodPickerSheet> createState() => _MethodPickerSheetState();
}

class _MethodPickerSheetState extends State<_MethodPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = PrayerMethodMapper.allMethods.where((entry) {
      if (_search.trim().isEmpty) return true;
      final q = _search.trim().toLowerCase();
      return entry.value.toLowerCase().contains(q);
    }).toList();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'اختر طريقة حساب المواقيت',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.emeraldDark,
              ),
            ),
            const SizedBox(height: 12),

            // Search box
            TextField(
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن هيئة أو دولة...',
                hintStyle: GoogleFonts.tajawal(color: AppColors.grey500, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.emerald),
                filled: true,
                fillColor: AppColors.cream,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
              onChanged: (val) => setState(() => _search = val),
            ),

            const SizedBox(height: 12),

            // List of methods
            Expanded(
              child: ListView(
                children: [
                  // Auto-detect option
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: widget.currentOverrideMethodId == null
                        ? AppColors.emeraldPale.withValues(alpha: 0.5)
                        : null,
                    leading: widget.currentOverrideMethodId == null
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.emerald)
                        : const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.grey300),
                    title: Text(
                      'تلقائي (حسب الدولة والموقع الجغرافي)',
                      style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: widget.currentOverrideMethodId == null
                            ? AppColors.emeraldDark
                            : AppColors.charcoal,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    subtitle: Text(
                      'يحدد الطريقة المعتمدة رسمياً في دولتك تلقائياً',
                      style: GoogleFonts.tajawal(fontSize: 11, color: AppColors.grey500),
                      textDirection: TextDirection.rtl,
                    ),
                    onTap: () => widget.onSelect(null),
                  ),

                  const Divider(color: AppColors.divider, height: 16),

                  // Method list
                  for (final entry in filtered) ...[
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: widget.currentOverrideMethodId == entry.key
                          ? AppColors.emeraldPale.withValues(alpha: 0.5)
                          : null,
                      leading: widget.currentOverrideMethodId == entry.key
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.emerald)
                          : const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.grey300),
                      title: Text(
                        entry.value,
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: widget.currentOverrideMethodId == entry.key
                              ? AppColors.emeraldDark
                              : AppColors.charcoal,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      trailing: Text(
                        'ID: ${entry.key}',
                        style: GoogleFonts.tajawal(fontSize: 11, color: AppColors.grey500),
                      ),
                      onTap: () => widget.onSelect(entry.key),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
