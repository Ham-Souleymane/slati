import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../domain/adhan_sound.dart';

class AdhanSoundSettingsScreen extends StatefulWidget {
  const AdhanSoundSettingsScreen({super.key});

  @override
  State<AdhanSoundSettingsScreen> createState() =>
      _AdhanSoundSettingsScreenState();
}

class _AdhanSoundSettingsScreenState extends State<AdhanSoundSettingsScreen>
    with TickerProviderStateMixin {
  String _selectedSoundId = AdhanSoundOption.defaultSoundId;
  bool _isMuted = false;
  String? _currentlyPlaying;
  bool _isLoading = true;

  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final soundId = await NotificationService.instance.getSelectedAdhanSound();
    final muted = await NotificationService.instance.isAdhanMuted();
    if (mounted) {
      setState(() {
        _selectedSoundId = soundId;
        _isMuted = muted;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectSound(AdhanSoundOption option) async {
    if (option.isSilent) {
      // "Silent" card toggles mute
      await _toggleMute(!_isMuted);
      return;
    }

    await _stopPreview();
    setState(() {
      _selectedSoundId = option.id;
      _isMuted = false; // unmute when selecting a sound
    });
    await NotificationService.instance.setAdhanMuted(false);
    await NotificationService.instance.setSelectedAdhanSound(option.id);
    if (mounted) {
      context.showSnackBar(
        context.tr('sound_applied_all'),
      );
    }
  }

  Future<void> _toggleMute(bool newValue) async {
    await _stopPreview();
    setState(() => _isMuted = newValue);
    await NotificationService.instance.setAdhanMuted(newValue);
    if (mounted) {
      context.showSnackBar(
        newValue
            ? context.tr('adhan_muted_msg')
            : context.tr('adhan_unmuted_msg'),
      );
    }
  }

  Future<void> _togglePreview(AdhanSoundOption option) async {
    if (option.isSilent) return;

    if (_currentlyPlaying == option.id) {
      await _stopPreview();
      return;
    }

    await _stopPreview();
    setState(() => _currentlyPlaying = option.id);
    await NotificationService.instance.playAdhanPreview(option.id);

    // Auto-stop after a reasonable preview duration (60s safety)
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted && _currentlyPlaying == option.id) {
        setState(() => _currentlyPlaying = null);
      }
    });
  }

  Future<void> _stopPreview() async {
    if (_currentlyPlaying != null) {
      setState(() => _currentlyPlaying = null);
      await NotificationService.instance.stopAdhanPreview();
    }
  }

  Future<void> _testInstant() async {
    await NotificationService.instance.showTestAdhanNotification(_selectedSoundId);
    if (mounted) {
      context.showSnackBar(context.tr('test_adhan_sent'));
    }
  }

  Future<void> _testOneMinuteAlarm() async {
    if (defaultTargetPlatform == TargetPlatform.android && mounted) {
      final isAr = _isLocaleArabic;

      // 1. Check Exact Alarm Permission
      final hasExact = await NotificationService.instance.hasExactAlarmPermission();
      if (!hasExact && mounted) {
        final shouldOpen = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isAr ? 'تنبيه إذن المنبهات الدقيقة ⏰' : 'Exact Alarms Permission ⏰',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.emeraldDark),
            ),
            content: Text(
              isAr
                  ? 'لضمان انطلاق صوت الأذان في الموعد المحدد بدقة 100% أثناء قفل الشاشة وإغلاق التطبيق، يرجى تفعيل إذن "المنبهات والتذكيرات" في نظام أندرويد.'
                  : 'To ensure the Adhan rings at the exact second when the screen is locked and the app is shut down, please enable the Alarms & Reminders permission in Android settings.',
              style: GoogleFonts.tajawal(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(isAr ? 'تخطي ومتابعة' : 'Skip & continue', style: GoogleFonts.tajawal(color: AppColors.grey700)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(isAr ? 'فتح الإعدادات للتفعيل' : 'Open Settings', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );

        if (shouldOpen == true) {
          await NotificationService.instance.requestExactAlarmPermission();
          return;
        }
      }

      // 2. Check Display Over Other Apps (Overlay) Permission
      final hasOverlay = await NotificationService.instance.hasOverlayPermission();
      if (!hasOverlay && mounted) {
        final shouldOpenOverlay = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isAr ? 'إذن إيقاظ الشاشة والظهور 📱' : 'Display Over Lock Screen 📱',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.emeraldDark),
            ),
            content: Text(
              isAr
                  ? 'لإيقاظ الشاشة وعرض شاشة الأذان فوق شاشة القفل عند إغلاق التطبيق في هواتف أندرويد الحديثة (Android 12+)، يرجى تفعيل إذن "الظهور فوق التطبيقات الأخرى".'
                  : 'To wake up the physical screen and display the Adhan screen over the lockscreen on Android 12+, please enable the "Display over other apps" permission in Android settings.',
              style: GoogleFonts.tajawal(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(isAr ? 'تخطي ومتابعة' : 'Skip & continue', style: GoogleFonts.tajawal(color: AppColors.grey700)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(isAr ? 'تفعيل الإذن الآن' : 'Enable Permission', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );

        if (shouldOpenOverlay == true) {
          await NotificationService.instance.requestOverlayPermission();
          return;
        }
      }
    }

    final success = await NotificationService.instance.scheduleTestAdhanInOneMinute(_selectedSoundId);
    if (!mounted) return;

    if (success) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.alarm_on_rounded, color: AppColors.emerald, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isLocaleArabic ? 'تمت جدولة الأذان التجريبي ⏱️' : 'Test Alarm Scheduled ⏱️',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppColors.emeraldDark,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isLocaleArabic
                    ? 'تمت جدولة موعد الأذان بعد دقيقة واحدة (60 ثانية) بالضبط!\n\n'
                      '📱 لتجربة التطبيق وهو مغلق بالكامل:\n'
                      '1️⃣ يمكنك الآن الخروج وإغلاق التطبيق نهائياً.\n'
                      '2️⃣ اقفل شاشة هاتفك المحمول.\n'
                      '3️⃣ انتظر 60 ثانية وستلاحظ إيقاظ الشاشة وبدء الأذان والإشعار فوراً.'
                    : 'The test Adhan has been scheduled in exactly 1 minute (60 seconds)!\n\n'
                      '📱 To test with the app completely killed:\n'
                      '1️⃣ You can now exit or swipe away/kill the app.\n'
                      '2️⃣ Lock your phone screen.\n'
                      '3️⃣ Wait 60 seconds and the phone will wake up and start the Adhan.',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                _isLocaleArabic ? 'حسناً، سأقفل الهاتف الآن' : 'Got it, locking screen now',
                style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    } else {
      context.showSnackBar(
        _isLocaleArabic ? 'تعذر جدولة التنبيه التجريبي' : 'Failed to schedule test alarm',
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    NotificationService.instance.stopAdhanPreview();
    super.dispose();
  }

  bool get _isLocaleArabic {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'ar';
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _isLocaleArabic;
    final sounds = AdhanSoundOption.allSounds;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.emeraldDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          context.tr('adhan_sound_settings'),
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.emerald),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                // ── Mute Banner ──────────────────────────────────
                _MuteBanner(
                  isMuted: _isMuted,
                  onToggle: (val) => _toggleMute(val),
                  isAr: isAr,
                ),

                const SizedBox(height: 24),

                // ── Section header ────────────────────────────────
                _SectionHeader(
                  title: context.tr('choose_adhan_sound'),
                ),
                const SizedBox(height: 12),

                // ── Sound Cards ───────────────────────────────────
                ...sounds.map((option) {
                  final isSelected = option.isSilent
                      ? _isMuted
                      : (_selectedSoundId == option.id && !_isMuted);
                  final isPlaying = _currentlyPlaying == option.id;
                  return _SoundCard(
                    option: option,
                    isSelected: isSelected,
                    isPlaying: isPlaying,
                    isMuted: _isMuted,
                    waveController: _waveController,
                    isAr: isAr,
                    onSelect: () => _selectSound(option),
                    onPreview: () => _togglePreview(option),
                  );
                }),

                const SizedBox(height: 28),

                // ── Permissions Section (Android) ──────────────────
                if (defaultTargetPlatform == TargetPlatform.android) ...[
                  _SectionHeader(
                    title: isAr ? 'أذونات إيقاظ الشاشة وعمل الأذان بالخلفية ⚙️' : 'Screen Wakeup & Background Permissions ⚙️',
                  ),
                  const SizedBox(height: 12),

                  _TestButton(
                    icon: Icons.layers_outlined,
                    iconColor: AppColors.emerald,
                    iconBgColor: AppColors.emeraldPale.withValues(alpha: 0.5),
                    label: isAr
                        ? 'إذن الظهور فوق التطبيقات وشاشة القفل'
                        : 'Display Over Other Apps & Lock Screen',
                    subtitle: isAr
                        ? 'ضروري جداً لإيقاظ الشاشة وعرض الأذان عند إغلاق التطبيق في أندرويد 12+'
                        : 'Crucial for waking the screen and popping up the ringing UI on Android 12+',
                    onTap: () async {
                      await NotificationService.instance.requestOverlayPermission();
                    },
                  ),

                  const SizedBox(height: 10),

                  _TestButton(
                    icon: Icons.alarm_outlined,
                    iconColor: AppColors.emerald,
                    iconBgColor: AppColors.emeraldPale.withValues(alpha: 0.5),
                    label: isAr ? 'إذن المنبهات الدقيقة (Alarm)' : 'Exact Alarms Permission',
                    subtitle: isAr
                        ? 'لضمان انطلاق صوت الأذان في الثانية المحددة بدقة'
                        : 'Ensures the adhan alarm fires at the exact second',
                    onTap: () async {
                      await NotificationService.instance.requestExactAlarmPermission();
                    },
                  ),

                  const SizedBox(height: 10),

                  _TestButton(
                    icon: Icons.battery_charging_full_rounded,
                    iconColor: AppColors.gold,
                    iconBgColor: AppColors.goldPale,
                    label: isAr ? 'استثناء التطبيق من تحسين البطارية' : 'Ignore Battery Optimizations',
                    subtitle: isAr
                        ? 'يمنع النظام من إيقاف الخدمة في الخلفية أثناء نوم الهاتف'
                        : 'Prevents the OS from killing the background service while idle',
                    onTap: () async {
                      await NotificationService.instance.requestIgnoreBatteryOptimizations();
                    },
                  ),

                  const SizedBox(height: 10),

                  _TestButton(
                    icon: Icons.settings_applications_outlined,
                    iconColor: AppColors.emeraldDark,
                    iconBgColor: AppColors.emeraldPale.withValues(alpha: 0.5),
                    label: isAr
                        ? 'إعدادات أذونات إضافية (لهواتف شاومي، سامسونج، أوبو)'
                        : 'Additional OEM Permissions (Xiaomi / Samsung / Oppo)',
                    subtitle: isAr
                        ? 'لتفعيل "العرض على شاشة القفل" و"التشغيل التلقائي Autostart" و"عرض النوافذ المنبثقة"'
                        : 'To enable "Show on lock screen", "Autostart", and "Pop-up windows" in system settings',
                    onTap: () async {
                      await NotificationService.instance.openAppSettings();
                    },
                  ),

                  const SizedBox(height: 28),
                ],

                // ── Test Buttons ──────────────────────────────────
                _SectionHeader(
                  title: isAr ? 'اختبار التنبيهات والأذان' : 'Test Adhan & Alarms',
                ),
                const SizedBox(height: 12),

                _TestButton(
                  icon: Icons.timer_outlined,
                  iconColor: AppColors.emerald,
                  iconBgColor: AppColors.emeraldPale.withValues(alpha: 0.5),
                  label: isAr
                      ? 'تجربة الأذان بعد دقيقة (مع إغلاق التطبيق وقفل الشاشة)'
                      : 'Test Adhan in 1 Min (App Shut Down & Locked)',
                  subtitle: isAr
                      ? 'اضغط هنا ثم أغلق التطبيق كلياً واقفل الشاشة للتأكد من انطلاق الأذان بعد 60 ثانية'
                      : 'Schedule in 60s, then kill the app and lock screen to verify background wakeup',
                  onTap: _testOneMinuteAlarm,
                ),

                const SizedBox(height: 10),

                _TestButton(
                  icon: Icons.volume_up_rounded,
                  iconColor: AppColors.gold,
                  iconBgColor: AppColors.goldPale,
                  label: context.tr('test_instant_alert'),
                  subtitle: _isMuted
                      ? (isAr ? 'سيتم إرسال إشعار فوري بدون صوت أذان' : 'Instant notification without sound')
                      : (isAr ? 'سيتم تشغيل الأذان المحدد فوراً' : 'Instant adhan playback now'),
                  onTap: _testInstant,
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Mute Banner
// ─────────────────────────────────────────────────────────
class _MuteBanner extends StatelessWidget {
  final bool isMuted;
  final ValueChanged<bool> onToggle;
  final bool isAr;

  const _MuteBanner({
    required this.isMuted,
    required this.onToggle,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isMuted
            ? AppColors.grey100
            : AppColors.emeraldDark.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMuted ? AppColors.grey300 : AppColors.emeraldLight.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              isMuted ? Icons.notifications_off_rounded : Icons.notifications_active_rounded,
              key: ValueKey(isMuted),
              color: isMuted ? AppColors.grey500 : AppColors.emerald,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMuted
                      ? (isAr ? 'كتم صوت الأذان (إشعارات فقط)' : 'Adhan Audio Muted')
                      : (isAr ? 'صوت الأذان مفعّل' : 'Adhan Audio Enabled'),
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isMuted ? AppColors.grey700 : AppColors.emeraldDark,
                  ),
                ),
                Text(
                  isMuted
                      ? (isAr ? 'ستتلقى إشعارات مرئية فقط' : 'You will receive visual notifications only')
                      : (isAr ? 'سيرفع الأذان المختار في وقت الصلاة' : 'Selected adhan will be called at prayer time'),
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    color: AppColors.grey500,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isMuted,
            onChanged: onToggle,
            thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.grey500 : AppColors.emerald),
            trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.grey300 : AppColors.emeraldLight.withValues(alpha: 0.25)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.tajawal(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.grey500,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Sound Card
// ─────────────────────────────────────────────────────────
class _SoundCard extends StatelessWidget {
  final AdhanSoundOption option;
  final bool isSelected;
  final bool isPlaying;
  final bool isMuted;
  final AnimationController waveController;
  final bool isAr;
  final VoidCallback onSelect;
  final VoidCallback onPreview;

  const _SoundCard({
    required this.option,
    required this.isSelected,
    required this.isPlaying,
    required this.isMuted,
    required this.waveController,
    required this.isAr,
    required this.onSelect,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final isSilentOption = option.isSilent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isSelected
                ? (isSilentOption
                    ? AppColors.grey100
                    : AppColors.emeraldDark.withValues(alpha: 0.07))
                : AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              width: isSelected ? 2 : 1,
              color: isSelected
                  ? (isSilentOption ? AppColors.grey300 : AppColors.emerald)
                  : AppColors.divider,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.06 : 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Icon ───────────────────────────────────────
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isSilentOption
                      ? AppColors.grey100
                      : (isSelected
                          ? AppColors.emerald.withValues(alpha: 0.12)
                          : AppColors.emeraldPale.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  option.icon,
                  color: isSilentOption
                      ? AppColors.grey500
                      : (isSelected ? AppColors.emerald : AppColors.emeraldMedium),
                  size: 22,
                ),
              ),

              const SizedBox(width: 14),

              // ── Title & Muazzin ────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title(isAr),
                      style: GoogleFonts.tajawal(
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 15,
                        color: isSilentOption
                            ? (isSelected ? AppColors.grey700 : AppColors.grey500)
                            : (isSelected
                                ? AppColors.emeraldDark
                                : AppColors.charcoal),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.muazzin(isAr),
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        color: AppColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── Right controls ─────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Selected badge
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSilentOption
                            ? AppColors.grey300
                            : AppColors.emerald,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isAr ? 'محدد' : 'Active',
                            style: GoogleFonts.tajawal(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Preview button (hidden for silent)
                  if (!isSilentOption)
                    _PreviewButton(
                      isPlaying: isPlaying,
                      waveController: waveController,
                      onTap: onPreview,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Preview Button with wave animation
// ─────────────────────────────────────────────────────────
class _PreviewButton extends StatelessWidget {
  final bool isPlaying;
  final AnimationController waveController;
  final VoidCallback onTap;

  const _PreviewButton({
    required this.isPlaying,
    required this.waveController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPlaying
              ? AppColors.emerald.withValues(alpha: 0.12)
              : AppColors.grey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPlaying ? AppColors.emerald : AppColors.grey300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPlaying) ...[
              AnimatedBuilder(
                animation: waveController,
                builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(3, (i) {
                    final h = 6.0 +
                        8 *
                            (waveController.value *
                                (i == 1 ? 1.0 : 0.6));
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Container(
                        width: 3,
                        height: h,
                        decoration: BoxDecoration(
                          color: AppColors.emerald,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 6),
            ] else ...[
              const Icon(Icons.play_arrow_rounded,
                  size: 16, color: AppColors.grey500),
              const SizedBox(width: 4),
            ],
            Text(
              isPlaying ? 'إيقاف' : 'استماع',
              style: GoogleFonts.tajawal(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPlaying ? AppColors.emerald : AppColors.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Test Button
// ─────────────────────────────────────────────────────────
class _TestButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _TestButton({
    required this.icon,
    this.iconColor,
    this.iconBgColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBgColor ?? AppColors.goldPale,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor ?? AppColors.gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.charcoal,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        color: AppColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.grey300, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
