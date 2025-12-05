import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../models/inventory_item.dart';
import '../utils/constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone database
      tz.initializeTimeZones();

      // Setup Android notification channel
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      // Setup iOS notification settings
      const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
      InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      // Create notification channel for Android
      await _createNotificationChannel();

      _isInitialized = true;
      print('Notification service initialized successfully');
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'expiration_channel',
      'Expiration Notifications',
      description: 'Notifications for pantry items expiring soon',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> scheduleExpirationNotification(InventoryItem item) async {
    if (!_isInitialized) await init();

    try {
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(item.expiryAt);

      // Schedule notifications for configured days before expiry
      for (final daysBefore in AppConstants.notificationDays) {
        final notificationDate = expiryDate.subtract(Duration(days: daysBefore));

        // Only schedule if notification date is in the future
        if (notificationDate.isAfter(DateTime.now())) {
          await _scheduleNotification(
            id: _generateNotificationId(item.id!, daysBefore),
            title: _getNotificationTitle(daysBefore),
            body: _getNotificationBody(item, daysBefore),
            scheduledDate: notificationDate,
            payload: item.id.toString(),
          );
        }
      }

      // Schedule expired notification for the expiry date
      if (expiryDate.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: _generateNotificationId(item.id!, -1),
          title: 'Item Expired Today',
          body: '${item.name} has expired. Consider disposing of it.',
          scheduledDate: expiryDate,
          payload: item.id.toString(),
        );
      }
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  int _generateNotificationId(int itemId, int daysBefore) {
    // Generate unique ID from item ID and days before expiry
    return itemId * 1000 + daysBefore + 1000;
  }

  String _getNotificationTitle(int daysBefore) {
    switch (daysBefore) {
      case 3:
        return 'Item Expiring Soon';
      case 1:
        return 'Item Expiring Tomorrow';
      case 0:
        return 'Item Expiring Today';
      default:
        return 'Pantry Item Notification';
    }
  }

  String _getNotificationBody(InventoryItem item, int daysBefore) {
    switch (daysBefore) {
      case 3:
        return '${item.name} expires in 3 days. Consider using it soon.';
      case 1:
        return '${item.name} expires tomorrow. Use it today!';
      case 0:
        return '${item.name} expires today.';
      default:
        return '${item.name} requires your attention.';
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'expiration_channel',
            'Expiration Notifications',
            channelDescription: 'Notifications for pantry items expiring soon',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            colorized: true,
            ticker: 'Pantry item expiring soon',
            styleInformation: const BigTextStyleInformation(''),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );


      print('Scheduled notification $id for ${scheduledDate.toString()}');
    } catch (e) {
      print('Error scheduling notification $id: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      print('Cancelled notification $id');
    } catch (e) {
      print('Error cancelling notification $id: $e');
    }
  }

  Future<void> cancelAllNotificationsForItem(int itemId) async {
    try {
      // Cancel all notifications for this item (3 days, 1 day, today, expired)
      final notificationIds = [
        _generateNotificationId(itemId, 3),
        _generateNotificationId(itemId, 1),
        _generateNotificationId(itemId, 0),
        _generateNotificationId(itemId, -1),
      ];

      for (final id in notificationIds) {
        await cancelNotification(id);
      }

      print('Cancelled all notifications for item $itemId');
    } catch (e) {
      print('Error cancelling notifications for item $itemId: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      print('Cancelled all notifications');
    } catch (e) {
      print('Error cancelling all notifications: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      print('Error getting pending notifications: $e');
      return [];
    }
  }

  Future<void> showTestNotification() async {
    if (!_isInitialized) await init();

    try {
      await _notificationsPlugin.show(
        999999,
        'Test Notification',
        'Pantry Tracker notifications are working!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'expiration_channel',
            'Expiration Notifications',
            channelDescription: 'Notifications for pantry items expiring soon',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      print('Error showing test notification: $e');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');

    // You could navigate to the specific item when notification is tapped
    if (response.payload != null) {
      final itemId = int.tryParse(response.payload!);
      if (itemId != null) {
        // TODO: Navigate to item details
        print('Navigate to item $itemId');
      }
    }
  }
}