import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../main.dart';
import '../models/task.dart';

Future<void> showNotification(Task activeTask) async {
  const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails('1', 'tasks',
          channelDescription: 'Channel for task completion',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker');
  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidNotificationDetails);
  await flutterLocalNotificationsPlugin.show(
      0,
      'Task Finished',
      'Congratulations! You have finished ${activeTask.name}',
      notificationDetails,
      payload: 'item x');
}
