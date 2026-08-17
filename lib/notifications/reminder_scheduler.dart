import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../reminders.dart';

final reminderSchedulerProvider =
    Provider((ref) => ReminderScheduler(FlutterLocalNotificationsPlugin()));

class ReminderScheduler {
  ReminderScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(settings: const InitializationSettings(android: androidInit));
  }

  // ponytail: schedules against UTC wall-clock time instead of the device's
  // real timezone (that needs the flutter_timezone plugin to detect it).
  // A reminder may fire a few hours off from local midnight; acceptable for
  // a single-user MVP — revisit if multi-timezone usage makes this visible.
  Future<void> scheduleAll(List<DueItem> items) async {
    await _plugin.cancelAll();
    final now = tz.TZDateTime.now(tz.UTC);
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final scheduledDate = tz.TZDateTime(
        tz.UTC,
        item.dueDate.year,
        item.dueDate.month,
        item.dueDate.day,
        9,
      );
      if (scheduledDate.isBefore(now)) continue;
      await _plugin.zonedSchedule(
        id: i,
        title: item.petName,
        body: item.label,
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('reminders', 'Rappels'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }
}
