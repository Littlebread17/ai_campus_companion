import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules on-device local notifications for reminders and events.
///
/// IMPORTANT: local notifications only fire on Android / iOS. On Flutter web
/// there is no OS-level scheduler, so every method here is a safe no-op when
/// [kIsWeb] is true. The app still stores lead-time / recurrence so that a
/// mobile build pings the student; the web build simply won't.
class ReminderScheduler {
  ReminderScheduler._();
  static final ReminderScheduler instance = ReminderScheduler._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Campus reminders and event alerts',
    importance: Importance.max,
    priority: Priority.high,
  );

  Future<void> initialize() async {
    if (kIsWeb || _ready) return;
    try {
      tzdata.initializeTimeZones();
      // Anchor tz.local to the device's real timezone so scheduled times are
      // interpreted correctly (the default is UTC otherwise).
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (e) {
        debugPrint('Local timezone lookup failed, using UTC: $e');
      }

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      await _requestPermissions();
      _ready = true;
    } catch (e) {
      debugPrint('ReminderScheduler init skipped: $e');
    }
  }

  /// Ask for notification permission (Android 13+ / iOS). Safe if already granted.
  Future<void> _requestPermissions() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('notification permission request failed: $e');
    }
  }

  /// A stable notification id derived from the Firestore doc id.
  static int idFor(String docId) => docId.hashCode & 0x7fffffff;

  /// Schedule a one-off notification at [when] minus [leadMinutes].
  /// Silently ignores times in the past.
  Future<void> schedule({
    required String docId,
    required String title,
    required String body,
    required DateTime when,
    int leadMinutes = 0,
  }) async {
    if (kIsWeb) return;
    await initialize();
    if (!_ready) return;
    final fireAt = when.subtract(Duration(minutes: leadMinutes));
    if (fireAt.isBefore(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        idFor(docId),
        title,
        body,
        tz.TZDateTime.from(fireAt, tz.local),
        const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('schedule failed: $e');
    }
  }

  Future<void> cancel(String docId) async {
    if (kIsWeb) return;
    await initialize();
    if (!_ready) return;
    try {
      await _plugin.cancel(idFor(docId));
    } catch (e) {
      debugPrint('cancel failed: $e');
    }
  }
}
