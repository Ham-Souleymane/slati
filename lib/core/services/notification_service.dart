import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Manages local prayer-time notifications.
///
/// Notification IDs are deterministic per prayer name so they can be
/// individually cancelled or rescheduled.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

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

    // Initialize timezone support
    tz.initializeTimeZones();

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

    // Request Android 13+ notification permission
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[NotificationService] Initialized with Timezones');
  }

  /// Schedules a one-shot local notification for [prayerName] at [time].
  ///
  /// If the time is in the past today the notification is skipped gracefully.
  /// Calling this again for the same prayer replaces the previous schedule.
  Future<void> schedulePrayerAlert(String prayerName, String timeStr) async {
    if (!_initialized) await initialize();

    final id = _prayerIds[prayerName] ?? 99;
    final parts = timeStr.split(':');
    if (parts.length < 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    // If the prayer time has already passed today, schedule it for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final androidDetails = AndroidNotificationDetails(
      'prayer_alerts_adhan',
      'تنبيهات الصلاة بالأذان',
      channelDescription: 'إشعارات مواقيت الصلاة وصوت الأذان',
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('adhan'),
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      sound: 'adhan.mp3',
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      'حان وقت $prayerName 🕌',
      'استعد للصلاة، وقتها $timeStr',
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint('[NotificationService] Scheduled "$prayerName" with Adhan at $scheduledDate (original time: $timeStr)');
  }

  /// Cancels the notification for [prayerName].
  Future<void> cancelPrayerAlert(String prayerName) async {
    if (!_initialized) await initialize();
    final id = _prayerIds[prayerName] ?? 99;
    await _plugin.cancel(id);
    debugPrint('[NotificationService] Cancelled "$prayerName"');
  }

  /// Cancels ALL prayer notifications.
  Future<void> cancelAll() async {
    if (!_initialized) await initialize();
    await _plugin.cancelAll();
    debugPrint('[NotificationService] Cancelled all notifications');
  }

  /// Initializes FCM listeners and requests permission. Call AFTER Firebase.initializeApp().
  Future<void> initializeFcm() async {
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
    onNotificationTap = (postId) {
      debugPrint('[NotificationService] Local notification tap, routing to post $postId');
      if (postId.isNotEmpty) {
        router.push('/post/$postId');
      }
    };

    // B. Handle tap when app is in the background and opened via system tray
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final postId = message.data['postId'];
      debugPrint('[NotificationService] Background notification tap, routing to post $postId');
      if (postId != null && postId.isNotEmpty) {
        router.push('/post/$postId');
      }
    });

    // C. Handle tap when app was terminated and opened via notification
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
    });
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
    // Listen to current auth changes (covers login, logout, app start)
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null && !user.isAnonymous) {
        await _saveTokenToFirestore(user.uid);
      }
    });

    // Listen to token refreshes
    FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        await _saveTokenToFirestore(user.uid);
      }
    });
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
