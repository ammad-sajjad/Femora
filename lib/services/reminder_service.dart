import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules Femora's local notifications (Android / iOS only): the monthly self-exam reminder, and the period,
/// fertile-window, daily-log and medication reminders. Nothing is sent to any server.
class ReminderService {
  static const _selfExamId = 3001;
  static const _hour = 10;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      // Unknown zone id: stays on UTC, so the reminder may arrive a few hours off
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Asks for permission, then repeats a reminder every month on [day] at 10:00.
  /// Returns false when notifications aren't supported or were not allowed.
  Future<bool> scheduleMonthly({required int day}) async {
    if (!isSupported) return false;
    try {
      await _init();
      if (!await _requestPermission()) return false;
      final now = tz.TZDateTime.now(tz.local);
      var first = tz.TZDateTime(tz.local, now.year, now.month, day, _hour);
      if (!first.isAfter(now)) first = tz.TZDateTime(tz.local, now.year, now.month + 1, day, _hour);
      await _plugin.zonedSchedule(
        id: _selfExamId,
        scheduledDate: first,
        title: 'Time for your monthly self-exam',
        body: 'It takes about 3 minutes. Open Femora for the step-by-step guide.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'self_exam',
            'Self-exam reminders',
            channelDescription: 'Monthly breast self-examination reminder',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // Inexact is fine for a monthly nudge and needs no exact-alarm permission
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
      return true;
    } catch (e) {
      debugPrint('Could not schedule self-exam reminder: $e');
      return false;
    }
  }

  Future<void> cancel() async {
    if (!isSupported) return;
    try {
      await _init();
      await _plugin.cancel(id: _selfExamId);
    } catch (e) {
      debugPrint('Could not cancel self-exam reminder: $e');
    }
  }


  /// Asks for permission to show notifications. Returns false when unsupported or refused.
  Future<bool> ensurePermission() async {
    if (!isSupported) return false;
    try {
      await _init();
      return await _requestPermission();
    } catch (e) {
      debugPrint('Could not ask for notification permission: $e');
      return false;
    }
  }

  /// Schedules one notification for the local wall-clock time [when]; repeats every day at that time when [repeatDaily].
  Future<bool> scheduleAt({
    required int id,
    required String channel,
    required String channelName,
    required String title,
    required String body,
    required DateTime when,
    bool repeatDaily = false,
  }) async {
    if (!isSupported) return false;
    try {
      await _init();
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime(tz.local, when.year, when.month, when.day, when.hour, when.minute),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(channel, channelName),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
      );
      return true;
    } catch (e) {
      debugPrint('Could not schedule reminder $id: $e');
      return false;
    }
  }

  /// Cancels the reminders with these ids.
  Future<void> cancelIds(Iterable<int> ids) async {
    if (!isSupported) return;
    try {
      await _init();
      for (final id in ids) {
        await _plugin.cancel(id: id);
      }
    } catch (e) {
      debugPrint('Could not cancel reminders: $e');
    }
  }

  Future<bool> _requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }
}
