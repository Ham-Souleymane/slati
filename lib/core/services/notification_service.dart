import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/prayer_times/domain/prayer_times_model.dart';

/// Manages local prayer-time notifications.
///
/// Notification IDs are deterministic per prayer name so they can be
/// individually cancelled or rescheduled.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const MethodChannel _nativeChannel = MethodChannel('com.slatk.slatkapp/adhan');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  PrayerTimes? _cachedTimes;
  String? _cachedCityName;
  Timer? _ongoingTimer;

  /// Adhan notification channel IDs for Android
  static const String adhanChannelId = 'prayer_alerts_adhan_v7';
  static const String adhanMakkahChannelId = 'prayer_alerts_adhan_makkah_v1';
  static const String adhanMadinaChannelId = 'prayer_alerts_adhan_madina_v1';
  static const String adhanDefaultChannelId = 'prayer_alerts_adhan_v7';
  static const String adhanSilentChannelId = 'prayer_alerts_silent_v1';

  /// Persistent silent notification channel ID for Android
  static const String ongoingChannelId = 'prayer_status_ongoing_v2';

  /// Fixed notification ID for the ongoing prayer bar
  static const int ongoingNotificationId = 777;

  /// Callback when a notification is tapped with a payload (e.g. postId)
  void Function(String postId)? onNotificationTap;

  // ── Prayer name → stable notification ID map ──────────────────
  static const Map<String, int> _prayerIds = {
    'الفجر': 0,
    'الشروق': 1,
    'الظهر': 2,
    'العصر': 3,
    'المغرب': 4,
    'العشاء': 5,
    'صلاة الجمعة': 6,
  };

  /// Must be called from [main] before [runApp].
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone database and set device local timezone using native platform timezone
    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('[NotificationService] Local timezone accurately set to: $timeZoneName');
    } catch (e) {
      debugPrint('[NotificationService] FlutterTimezone error: $e. Falling back to offset.');
      try {
        final now = DateTime.now();
        final timeZoneName = now.timeZoneName;
        if (tz.timeZoneDatabase.locations.containsKey(timeZoneName)) {
          tz.setLocalLocation(tz.getLocation(timeZoneName));
        } else {
          final offsetMs = now.timeZoneOffset.inMilliseconds;
          for (final loc in tz.timeZoneDatabase.locations.values) {
            if (loc.currentTimeZone.offset == offsetMs) {
              tz.setLocalLocation(loc);
              break;
            }
          }
        }
      } catch (e2) {
        debugPrint('[NotificationService] Timezone fallback setup error: $e2');
      }
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: iOS),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty && onNotificationTap != null) {
          onNotificationTap!(payload);
        }
      },
    );

    // Create high-priority Adhan notification channels for Android 8.0+
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Delete old channel versions
    for (final oldId in [
      'prayer_alerts_adhan_v1',
      'prayer_alerts_adhan_v2',
      'prayer_alerts_adhan_v3',
      'prayer_alerts_adhan_v4',
      'prayer_alerts_adhan_v5',
      'prayer_alerts_adhan_v6',
      'prayer_status_ongoing_v1',
    ]) {
      try {
        await androidImpl?.deleteNotificationChannel(oldId);
      } catch (_) {}
    }

    const makkahChannel = AndroidNotificationChannel(
      adhanMakkahChannelId,
      'أذان الحرم المكي الشريف',
      description: 'إشعارات مواقيت الصلاة بصوت أذان مكة المكرمة',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('adhan_makkah'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
    );

    const madinaChannel = AndroidNotificationChannel(
      adhanMadinaChannelId,
      'أذان المسجد النبوي الشريف',
      description: 'إشعارات مواقيت الصلاة بصوت أذان المدينة المنورة',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('adhan_madina'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
    );

    const defaultChannel = AndroidNotificationChannel(
      adhanDefaultChannelId,
      'تنبيهات الصلاة بالأذان (الافتراضي)',
      description: 'إشعارات مواقيت الصلاة وصوت الأذان الكلاسيكي',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('adhan'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
    );

    const silentChannel = AndroidNotificationChannel(
      adhanSilentChannelId,
      'تنبيهات الصلاة الصامتة (إشعار فقط)',
      description: 'إشعارات مواقيت الصلاة بدون صوت أذان',
      importance: Importance.high,
      playSound: false,
      enableVibration: true,
    );

    const ongoingChannel = AndroidNotificationChannel(
      ongoingChannelId,
      'شريط مواقيت الصلاة المستمر',
      description: 'عرض التاريخ الهجري والصلاة القادمة والعداد التنازلي بشكل دائم في شريط الإشعارات',
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await androidImpl?.createNotificationChannel(makkahChannel);
    await androidImpl?.createNotificationChannel(madinaChannel);
    await androidImpl?.createNotificationChannel(defaultChannel);
    await androidImpl?.createNotificationChannel(silentChannel);
    await androidImpl?.createNotificationChannel(ongoingChannel);
    await androidImpl?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[NotificationService] Initialized with Adhan Sound channels, Ongoing channel and Timezones');
  }

  /// Parses a time string (e.g. "05:24", "5:24", "05:24 (EET)", "04:30 م") into a local [DateTime].
  static DateTime? parseTimeToDateTime(String timeStr, DateTime baseDate, [String? prayerName]) {
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
        if (prayerName.contains('ظهر') && hour >= 1 && hour <= 10) hour += 12;
        if (prayerName.contains('عصر') && hour < 12) hour += 12;
        if (prayerName.contains('مغرب') && hour < 12) hour += 12;
        if (prayerName.contains('عشاء') && hour < 12) hour += 12;
      }

      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  /// Returns true if the app can schedule exact alarms on Android 12+.
  Future<bool> hasExactAlarmPermission() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final res = await _nativeChannel.invokeMethod<bool>('canScheduleExactAlarms');
        if (res != null) return res;
      } catch (_) {}
    }
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true; // Not Android
    try {
      return await androidImpl.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests exact alarm permission. On Android 12+ this opens System Settings.
  Future<void> requestExactAlarmPermission() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('openExactAlarmSettings');
        return;
      } catch (_) {}
    }
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;
    try {
      await androidImpl.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('[NotificationService] requestExactAlarmsPermission error: $e');
    }
  }

  /// Returns true if the app has permission to display over other apps (critical on OEM Android 12+).
  Future<bool> hasOverlayPermission() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final res = await _nativeChannel.invokeMethod<bool>('canDrawOverlays');
        if (res != null) return res;
      } catch (_) {}
    }
    return true; // Not Android
  }

  /// Opens system settings so user can enable "Display over other apps" / "Show on Lock screen".
  Future<void> requestOverlayPermission() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('openOverlaySettings');
      } catch (e) {
        debugPrint('[NotificationService] requestOverlayPermission error: $e');
      }
    }
  }

  /// Returns true if battery optimizations are disabled (whitelisted) for the app on Android.
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final res = await _nativeChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
        if (res != null) return res;
      } catch (_) {}
    }
    return true; // Not Android or default
  }

  /// Requests to ignore battery optimizations so the Adhan rings reliably in the background.
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      } catch (e) {
        debugPrint('[NotificationService] requestIgnoreBatteryOptimizations error: $e');
      }
    }
  }

  /// Opens App Info / Details settings (vital for Xiaomi/Redmi/Poco "Other Permissions" like Show on Lock screen & Autostart).
  Future<void> openAppSettings() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('openAppSettings');
      } catch (e) {
        debugPrint('[NotificationService] openAppSettings error: $e');
      }
    }
  }

  /// Helper to resolve channel ID and sound for a given sound key and mute flag.
  ({String channelId, String? rawSound, bool playSound, String? iosSound}) _getChannelDetails(String soundKey, bool isMuted) {
    if (isMuted || soundKey == 'silent' || soundKey == 'adhan_none') {
      return (
        channelId: adhanSilentChannelId,
        rawSound: null,
        playSound: false,
        iosSound: null,
      );
    }
    if (soundKey == 'adhan_madina') {
      return (
        channelId: adhanMadinaChannelId,
        rawSound: 'adhan_madina',
        playSound: true,
        iosSound: 'adhan_madina.mp3',
      );
    }
    if (soundKey == 'adhan_default' || soundKey == 'adhan') {
      return (
        channelId: adhanDefaultChannelId,
        rawSound: 'adhan',
        playSound: true,
        iosSound: 'adhan.mp3',
      );
    }
    return (
      channelId: adhanMakkahChannelId,
      rawSound: 'adhan_makkah',
      playSound: true,
      iosSound: 'adhan_makkah.mp3',
    );
  }

  /// Returns the selected Adhan sound ID for [prayerName] (or global default if null).
  Future<String> getSelectedAdhanSound([String? prayerName]) async {
    final sp = await SharedPreferences.getInstance();
    if (prayerName != null) {
      final specific = sp.getString('adhan_sound_$prayerName');
      if (specific != null && specific.isNotEmpty) return specific;
    }
    return sp.getString('selected_adhan_sound') ?? 'adhan_makkah';
  }

  /// Sets the selected Adhan sound ID globally or for a specific [prayerName].
  Future<void> setSelectedAdhanSound(String soundId, [String? prayerName]) async {
    final sp = await SharedPreferences.getInstance();
    if (prayerName != null) {
      await sp.setString('adhan_sound_$prayerName', soundId);
    } else {
      await sp.setString('selected_adhan_sound', soundId);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('setAdhanSound', {
          'soundKey': soundId,
          if (prayerName != null) 'prayerName': prayerName,
        });
      } catch (e) {
        debugPrint('[NotificationService] setAdhanSound error: $e');
      }
    }
  }

  /// Returns whether Adhan audio is muted (notifications only) for [prayerName] or globally.
  Future<bool> isAdhanMuted([String? prayerName]) async {
    final sp = await SharedPreferences.getInstance();
    if (prayerName != null && sp.containsKey('adhan_muted_$prayerName')) {
      return sp.getBool('adhan_muted_$prayerName') ?? false;
    }
    return sp.getBool('adhan_muted') ?? false;
  }

  /// Sets whether Adhan audio is muted (notifications only) globally or for [prayerName].
  Future<void> setAdhanMuted(bool isMuted, [String? prayerName]) async {
    final sp = await SharedPreferences.getInstance();
    if (prayerName != null) {
      await sp.setBool('adhan_muted_$prayerName', isMuted);
    } else {
      await sp.setBool('adhan_muted', isMuted);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('setAdhanMuted', {
          'isMuted': isMuted,
          if (prayerName != null) 'prayerName': prayerName,
        });
      } catch (e) {
        debugPrint('[NotificationService] setAdhanMuted error: $e');
      }
    }
  }

  /// Plays a preview of the specified Adhan sound.
  Future<void> playAdhanPreview(String soundId) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('previewAdhan', {'soundKey': soundId});
      } catch (e) {
        debugPrint('[NotificationService] playAdhanPreview error: $e');
      }
    }
  }

  /// Stops any currently playing Adhan preview.
  Future<void> stopAdhanPreview() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('stopPreview');
      } catch (e) {
        debugPrint('[NotificationService] stopAdhanPreview error: $e');
      }
    }
  }

  /// Schedules a daily repeating local notification for [prayerName] at [timeStr] with Adhan sound.
  Future<bool> schedulePrayerAlert(String prayerName, String timeStr, [String? soundOverride]) async {
    if (!_initialized) await initialize();

    final sp = await SharedPreferences.getInstance();
    final isMuted = sp.getBool('adhan_muted_$prayerName') ?? (sp.getBool('adhan_muted') ?? false);
    final soundKey = soundOverride 
        ?? sp.getString('adhan_sound_$prayerName') 
        ?? (sp.getString('selected_adhan_sound') ?? 'adhan_makkah');

    // Schedule directly via native Android AlarmClock & Foreground Service
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('schedulePrayer', {
          'prayerName': prayerName,
          'timeStr': timeStr,
          'soundKey': isMuted ? 'silent' : soundKey,
        });
        debugPrint('[NotificationService] Native Android alarm scheduled for $prayerName at $timeStr (sound: $soundKey, muted: $isMuted)');
        return true;
      } catch (e) {
        debugPrint('[NotificationService] Native Android schedulePrayer error: $e');
      }
    }

    final id = _prayerIds[prayerName] ?? 99;
    final now = DateTime.now();
    final scheduledDate = parseTimeToDateTime(timeStr, now, prayerName);
    if (scheduledDate == null) {
      debugPrint('[NotificationService] Could not parse time "$timeStr" for $prayerName');
      return false;
    }

    final tzNow = tz.TZDateTime.now(tz.local);
    var tzScheduledDate = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      scheduledDate.hour,
      scheduledDate.minute,
    );

    // If the prayer time has already passed today, schedule it for tomorrow
    if (tzScheduledDate.isBefore(tzNow)) {
      tzScheduledDate = tzScheduledDate.add(const Duration(days: 1));
    }

    final ch = _getChannelDetails(soundKey, isMuted);

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: ch.playSound,
      sound: ch.iosSound,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(iOS: iosDetails);

    try {
      await _plugin.zonedSchedule(
        id,
        'حان وقت $prayerName 🕌',
        'استعد للصلاة، وقتها $timeStr',
        tzScheduledDate,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint(
          '[NotificationService] Scheduled "$prayerName" (iOS, repeating daily) at $tzScheduledDate (sound: $soundKey)');
      return true;
    } catch (e) {
      debugPrint('[NotificationService] zonedSchedule error for "$prayerName": $e');
      return false;
    }
  }

  /// Schedules a test alarm in exactly 1 minute so the user can lock the phone and verify background alarm wakeup.
  Future<bool> scheduleTestAdhanInOneMinute([String? testSound]) async {
    if (!_initialized) await initialize();

    final sp = await SharedPreferences.getInstance();
    final isMuted = sp.getBool('adhan_muted') ?? false;
    final soundKey = testSound ?? (sp.getString('selected_adhan_sound') ?? 'adhan_makkah');

    // 1. Trigger native Android AlarmClock & background service
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final res = await _nativeChannel.invokeMethod<bool>('scheduleTestAlarm', {
          'soundKey': isMuted ? 'silent' : soundKey,
        });
        final nativeSuccess = res ?? true;
        debugPrint('[NotificationService] Native Android scheduled 1-min test alarm: $nativeSuccess');
        return nativeSuccess;
      } catch (e) {
        debugPrint('[NotificationService] Native Android scheduleTestAlarm error: $e');
      }
    }

    // 2. Schedule via flutter_local_notifications plugin (for iOS)
    final now = DateTime.now();
    final testTime = now.add(const Duration(minutes: 1));
    final tzScheduledDate = tz.TZDateTime.from(testTime, tz.local);

    final ch = _getChannelDetails(soundKey, isMuted);

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: ch.playSound,
      sound: ch.iosSound,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(iOS: iosDetails);

    try {
      await _plugin.zonedSchedule(
        999,
        '🕌 تجربة الأذان بعد دقيقة',
        isMuted ? 'تنبيه تجريبي (إشعار فقط بدون صوت)' : 'حان موعد التنبيه التجريبي بالأذان!',
        tzScheduledDate,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('[NotificationService] Scheduled 1-min test alarm (iOS) at $tzScheduledDate');
      return true;
    } catch (e) {
      debugPrint('[NotificationService] scheduleTestAdhanInOneMinute error: $e');
      return false;
    }
  }

  /// Triggers an immediate test notification with Adhan sound for verification.
  Future<void> showTestAdhanNotification([String? testSound]) async {
    if (!_initialized) await initialize();

    final sp = await SharedPreferences.getInstance();
    final isMuted = sp.getBool('adhan_muted') ?? false;
    final soundKey = testSound ?? (sp.getString('selected_adhan_sound') ?? 'adhan_makkah');

    // Play native Adhan service immediately
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('playTestAdhan', {
          'soundKey': isMuted ? 'silent' : soundKey,
        });
      } catch (e) {
        debugPrint('[NotificationService] Native Android playTestAdhan error: $e');
      }
    }

    final ch = _getChannelDetails(soundKey, isMuted);
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    final androidDetails = AndroidNotificationDetails(
      isAndroid ? adhanSilentChannelId : ch.channelId,
      'تنبيهات الصلاة بالأذان',
      channelDescription: 'إشعارات مواقيت الصلاة وصوت الأذان',
      importance: Importance.max,
      priority: Priority.max,
      sound: isAndroid ? null : (ch.rawSound != null ? RawResourceAndroidNotificationSound(ch.rawSound!) : null),
      playSound: !isAndroid && ch.playSound,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      icon: '@mipmap/ic_launcher',
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: ch.playSound,
      sound: ch.iosSound,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(
      888,
      '🕌 اختبار أذان وتنبيهات الصلاة',
      isMuted ? 'تم إرسال إشعار التجربة (صامت بدون صوت أذان)' : 'صوت الأذان والإشعارات تعمل بشكل سليم!',
      details,
    );
  }

  /// Syncs and schedules prayer alerts based on SharedPreferences settings.
  Future<void> syncPrayerAlerts(PrayerTimes times, [SharedPreferences? prefs]) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final Map<String, String> prayersMap = {};
    final Map<String, bool> enabledMap = {};
    final Map<String, String> soundsMap = {};

    final globalSound = sp.getString('selected_adhan_sound') ?? 'adhan_makkah';
    final globalMuted = sp.getBool('adhan_muted') ?? false;

    for (final entry in times.allPrayers) {
      final prayerName = entry.key;
      final timeStr = entry.value;
      // Default to true for the 5 daily prayers; Sunrise (الشروق) is not a prayer
      final enabled = sp.getBool('alert_$prayerName') ?? (prayerName != 'الشروق');
      final prayerMuted = sp.getBool('adhan_muted_$prayerName') ?? globalMuted;
      final prayerSound = prayerMuted 
          ? 'silent' 
          : (sp.getString('adhan_sound_$prayerName') ?? globalSound);

      prayersMap[prayerName] = timeStr;
      enabledMap[prayerName] = enabled;
      soundsMap[prayerName] = prayerSound;

      if (enabled) {
        await schedulePrayerAlert(prayerName, timeStr, prayerSound);
      } else {
        await cancelPrayerAlert(prayerName);
      }
    }

    // Synchronize native Android scheduler
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('scheduleAll', {
          'prayers': prayersMap,
          'enabled': enabledMap,
          'sounds': soundsMap,
        });
        debugPrint('[NotificationService] Native Android synced all prayer alarms with custom sounds');
      } catch (e) {
        debugPrint('[NotificationService] Native Android scheduleAll error: $e');
      }
    }
  }

  /// Cancels the notification for [prayerName].
  Future<void> cancelPrayerAlert(String prayerName) async {
    if (!_initialized) await initialize();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod('cancelPrayer', {'prayerName': prayerName});
      } catch (e) {
        debugPrint('[NotificationService] Native Android cancelPrayer error: $e');
      }
    }

    final id = _prayerIds[prayerName] ?? 99;
    await _plugin.cancel(id);
    debugPrint('[NotificationService] Cancelled "$prayerName"');
  }

  /// Returns the formatted Hijri date with optional city name, e.g. "14 ربيع الأول 1448 | الشلف"
  static String getFormattedHijriDate([String? cityName]) {
    final hijri = HijriCalendar.now();
    const months = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الثاني',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة'
    ];
    final monthName = (hijri.hMonth >= 1 && hijri.hMonth <= 12)
        ? months[hijri.hMonth - 1]
        : '';
    final dateStr = '${hijri.hDay} $monthName ${hijri.hYear} هـ';
    if (cityName != null && cityName.trim().isNotEmpty) {
      return '$dateStr | ${cityName.trim()}';
    }
    return dateStr;
  }

  static String _getOngoingNotificationBody(PrayerTimes times, [String? cityName]) {
    final now = DateTime.now();
    final next = times.nextPrayer(now);
    final nextPrayerName = next?.key ?? 'الفجر';
    final nextPrayerTime = next?.value ?? times.fajr;
    final hijri = getFormattedHijriDate(cityName);
    return 'صلاة $nextPrayerName: $nextPrayerTime • $hijri';
  }

  void _startOngoingTimer() {
    _ongoingTimer?.cancel();
    _ongoingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_cachedTimes != null) {
        updateOngoingPrayerStatus(
          times: _cachedTimes!,
          cityName: _cachedCityName,
          fromTimer: true,
        );
      }
    });
  }

  /// Updates or shows the persistent (ongoing) silent notification in the notification shade (Salatuk style).
  Future<void> updateOngoingPrayerStatus({
    required PrayerTimes times,
    String? cityName,
    bool fromTimer = false,
  }) async {
    _cachedTimes = times;
    if (cityName != null && cityName.isNotEmpty) {
      _cachedCityName = cityName;
    }
    if (!fromTimer) {
      _startOngoingTimer();
    }

    if (!_initialized) await initialize();

    final sp = await SharedPreferences.getInstance();
    final enabled = sp.getBool('ongoing_prayer_notification') ?? true;
    if (!enabled) return;

    final now = DateTime.now();
    final next = times.nextPrayer(now);
    DateTime? nextDt;
    final String nextPrayerName;
    final String nextPrayerTime;

    if (next != null) {
      nextPrayerName = next.key;
      nextPrayerTime = next.value;
      nextDt = parseTimeToDateTime(next.value, now);
      if (nextDt != null && nextDt.isBefore(now)) {
        nextDt = nextDt.add(const Duration(days: 1));
      }
    } else {
      nextPrayerName = 'الفجر';
      nextPrayerTime = times.fajr;
      nextDt = parseTimeToDateTime(times.fajr, now.add(const Duration(days: 1)));
    }

    final cityDisplay = _cachedCityName ?? cityName;
    final title = '🕌 الصلاة القادمة: $nextPrayerName ($nextPrayerTime)';
    final body = _getOngoingNotificationBody(times, cityDisplay);

    final bigTextStyle = BigTextStyleInformation(
      '⏳ الوقت المتبقي حتى الأذان قيد العد التنازلي ⏱️\n'
      '🕌 الصلاة القادمة: $nextPrayerName في تمام الساعة $nextPrayerTime\n'
      '📅 التاريخ: ${getFormattedHijriDate(cityDisplay)}',
      contentTitle: title,
      summaryText: 'العد التنازلي للصلاة ⏱️',
      htmlFormatContent: false,
      htmlFormatTitle: false,
    );

    final androidDetails = AndroidNotificationDetails(
      ongoingChannelId,
      'شريط مواقيت الصلاة المستمر',
      channelDescription: 'عرض التاريخ الهجري والصلاة القادمة والعداد التنازلي بشكل دائم في شريط الإشعارات',
      importance: Importance.defaultImportance,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: nextDt != null,
      when: nextDt?.millisecondsSinceEpoch,
      usesChronometer: nextDt != null,
      chronometerCountDown: true,
      styleInformation: bigTextStyle,
      subText: cityDisplay ?? 'مواقيت الصلاة',
      color: const Color(0xFF1B5E20),
      silent: true,
      category: AndroidNotificationCategory.status,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentSound: false,
      presentBadge: false,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _plugin.show(
        ongoingNotificationId,
        title,
        body,
        details,
        payload: 'prayer_times',
      );
      debugPrint('[NotificationService] Updated prominent ongoing prayer notification: $title | $body');
    } catch (e) {
      debugPrint('[NotificationService] updateOngoingPrayerStatus error: $e');
    }
  }

  /// Dismisses the persistent ongoing prayer notification.
  Future<void> cancelOngoingPrayerStatus() async {
    _ongoingTimer?.cancel();
    if (!_initialized) await initialize();
    try {
      await _plugin.cancel(ongoingNotificationId);
      debugPrint('[NotificationService] Cancelled ongoing prayer notification');
    } catch (e) {
      debugPrint('[NotificationService] cancelOngoingPrayerStatus error: $e');
    }
  }

  /// Enables or disables the persistent prayer notification setting.
  Future<void> setOngoingPrayerStatusEnabled(bool enabled, [PrayerTimes? times, String? cityName]) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('ongoing_prayer_notification', enabled);
    if (enabled && times != null) {
      await updateOngoingPrayerStatus(times: times, cityName: cityName);
    } else if (!enabled) {
      await cancelOngoingPrayerStatus();
    }
  }

  /// Checks if the persistent prayer notification is enabled.
  Future<bool> isOngoingPrayerStatusEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool('ongoing_prayer_notification') ?? true;
  }

  /// Cancels ALL prayer notifications.
  Future<void> cancelAll() async {
    if (!_initialized) await initialize();
    await _plugin.cancelAll();
    debugPrint('[NotificationService] Cancelled all notifications');
  }

  /// Initializes FCM listeners and requests permission. Call AFTER Firebase.initializeApp().
  Future<void> initializeFcm() async {
    // FCM push notifications are not supported on Flutter Web.
    if (kIsWeb) {
      debugPrint('[NotificationService] Skipping FCM init on Web.');
      return;
    }

    try {
      final fcm = FirebaseMessaging.instance;

      // 1. Request notification permission for FCM
      await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2. Set up foreground messages listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM] Foreground message received: ${message.notification?.title}');
        final notification = message.notification;
        if (notification != null) {
          showNotification(
            id: notification.hashCode,
            title: notification.title ?? '',
            body: notification.body ?? '',
            payload: message.data['postId'],
          );
        }
      });

      // 3. Start token syncing
      _startTokenSync();

      debugPrint('[NotificationService] FCM initialized successfully');
    } catch (e) {
      debugPrint('[NotificationService] Error initializing FCM: $e');
    }
  }

  /// Registers listeners for notification click/tap navigation.
  void setupFcmNavigation(GoRouter router) {
    // A. Handle tap on local notifications shown in the foreground
    onNotificationTap = (payload) {
      debugPrint('[NotificationService] Notification tap with payload: $payload');
      if (payload == 'prayer_times') {
        router.go('/prayer-times');
      } else if (payload.isNotEmpty) {
        router.push('/post/$payload');
      }
    };

    // FCM deep-link listeners are not available on Flutter Web.
    if (kIsWeb) {
      debugPrint('[NotificationService] Skipping FCM navigation setup on Web.');
      return;
    }

    // B. Handle tap when app is in the background and opened via system tray
    try {
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final postId = message.data['postId'];
        debugPrint('[NotificationService] Background notification tap, routing to post $postId');
        if (postId != null && postId.isNotEmpty) {
          router.push('/post/$postId');
        }
      });
    } catch (e) {
      debugPrint('[NotificationService] onMessageOpenedApp listener error: $e');
    }

    // C. Handle tap when app was terminated and opened via notification
    try {
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          final postId = message.data['postId'];
          debugPrint('[NotificationService] Terminated notification tap, routing to post $postId');
          if (postId != null && postId.isNotEmpty) {
            // Wait a frame to ensure router and widgets are mounted
            WidgetsBinding.instance.addPostFrameCallback((_) {
              router.push('/post/$postId');
            });
          }
        }
      }).catchError((e) {
        debugPrint('[NotificationService] getInitialMessage error: $e');
      });
    } catch (e) {
      debugPrint('[NotificationService] getInitialMessage setup error: $e');
    }
  }

  /// Shows a notification with details.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'post_notifications',
      'منشورات المساجد',
      channelDescription: 'إشعارات المنشورات الجديدة من المساجد المتابعة',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, title, body, details, payload: payload);
  }

  void _startTokenSync() {
    if (kIsWeb) return;

    // Listen to current auth changes (covers login, logout, app start)
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null && !user.isAnonymous) {
        await _saveTokenToFirestore(user.uid);
      }
    });

    // Listen to token refreshes
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.isAnonymous) {
          await _saveTokenToFirestore(user.uid);
        }
      });
    } catch (e) {
      debugPrint('[NotificationService] onTokenRefresh listener error: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
        debugPrint('[NotificationService] FCM token successfully saved/merged for user $uid');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error saving FCM token to Firestore: $e');
    }
  }
}
