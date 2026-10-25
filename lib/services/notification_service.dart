import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications: an always-visible status bar (Android) and periodic
/// scan reminders. Everything is generated on the device; nothing is sent anywhere.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int _statusId = 1001;
  static const int _reminderId = 2001;
  static const int _previewId = 3001;

  final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Incremented when the user taps the notification (or its "Quick scan" action).
  final ValueNotifier<int> scanRequests = ValueNotifier<int>(0);

  bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (_ready) return;
    try {
      const init = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _p.initialize(
        init,
        onDidReceiveNotificationResponse: (r) {
          if (r.actionId == 'scan' || r.payload == 'scan') scanRequests.value++;
        },
      );
      _ready = true;
      final launch = await _p.getNotificationAppLaunchDetails();
      final resp = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) &&
          resp != null &&
          (resp.actionId == 'scan' || resp.payload == 'scan')) {
        scanRequests.value++;
      }
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final a = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (a != null) return (await a.requestNotificationsPermission()) ?? false;
      final i = _p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (i != null) return (await i.requestPermissions(alert: true, badge: false, sound: false)) ?? false;
    } catch (e) {
      debugPrint('notification permission failed: $e');
    }
    return false;
  }

  // ---- persistent status bar (Android) ----
  Future<void> showStatus({
    required String title,
    required String body,
    required String actionLabel,
  }) async {
    if (!_ready || !isAndroid) return;
    try {
      await _p.show(
        _statusId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'status',
            'Storage status',
            channelDescription: 'Always-visible summary of what can be cleaned',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: false,
            playSound: false,
            enableVibration: false,
            actions: [
              AndroidNotificationAction('scan', actionLabel, showsUserInterface: true, cancelNotification: false),
            ],
          ),
        ),
        payload: 'scan',
      );
    } catch (e) {
      debugPrint('status notification failed: $e');
    }
  }

  Future<void> hideStatus() async {
    if (!_ready) return;
    try {
      await _p.cancel(_statusId);
    } catch (_) {}
  }

  // ---- reminders ----
  /// [mode]: 0 off, 1 daily, 2 weekly.
  Future<void> setReminder(int mode, {required String title, required String body}) async {
    if (!_ready) return;
    try {
      await _p.cancel(_reminderId);
      if (mode == 0) return;
      await _p.periodicallyShow(
        _reminderId,
        title,
        body,
        mode == 1 ? RepeatInterval.daily : RepeatInterval.weekly,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder',
            'Scan reminders',
            channelDescription: 'Reminds you to clean up your photos',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: 'scan',
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('reminder failed: $e');
    }
  }

  Future<void> preview({required String title, required String body}) async {
    if (!_ready) return;
    try {
      await _p.show(
        _previewId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder',
            'Scan reminders',
            channelDescription: 'Reminds you to clean up your photos',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: 'scan',
      );
    } catch (e) {
      debugPrint('preview failed: $e');
    }
  }
}
