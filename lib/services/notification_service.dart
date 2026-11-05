import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/important_date.dart';

/// Reminder notifications at 9:00 am, 90/60/30/7 days before each due date.
///
/// Permission is requested contextually - the first time a record with
/// reminders is saved - just like the native app.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get _supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'important_dates_reminders',
      'Important Date Reminders',
      channelDescription: 'Reminders before an Important Date is due',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    macOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
  );

  static Future<void> init() async {
    if (!_supported) return;
    try {
      tzdata.initializeTimeZones();
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwin,
        macOS: darwin,
      ));
      _ready = true;
    } catch (e) {
      debugPrint('Notification setup failed: $e');
    }
  }

  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (Platform.isIOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      if (Platform.isMacOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      if (Platform.isAndroid) {
        return await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }
    return false;
  }

  /// Stable 31-bit id for one reminder of one record (FNV-1a hash).
  static int _id(String recordId, int days) {
    var h = 0x811c9dc5;
    for (final c in '$recordId-$days'.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h & 0x7FFFFFFF;
  }

  static Future<void> cancel(ImportantDate item) async {
    if (!_ready) return;
    for (final days in {90, 60, 30, 7, item.notificationDays}) {
      await _plugin.cancel(_id(item.id, days));
    }
  }

  static Future<void> schedule(ImportantDate item, {bool requestPermission = false}) async {
    if (!_ready) return;
    await cancel(item);
    if (item.isAccomplished) return;
    if (requestPermission) {
      final granted = await NotificationService.requestPermission();
      if (!granted) return;
    }
    final selected = item.selectedReminderDays;
    final reminderDays = selected.isEmpty ? {item.notificationDays} : selected.toSet();
    final now = DateTime.now();
    for (final days in reminderDays) {
      final day = item.dueDate.subtract(Duration(days: days));
      final fireLocal = DateTime(day.year, day.month, day.day, 9);
      if (!fireLocal.isAfter(now)) continue;
      try {
        await _plugin.zonedSchedule(
          _id(item.id, days),
          'Important Date Reminder',
          '${item.item} for ${item.name} is due in $days days.',
          tz.TZDateTime.from(fireLocal.toUtc(), tz.UTC),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Notification schedule error: $e');
      }
    }
  }

  static Future<void> rescheduleAll(List<ImportantDate> items) async {
    if (!_ready) return;
    await cancelAll();
    for (final item in items) {
      await schedule(item);
    }
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }
}
