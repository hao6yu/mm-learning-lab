import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../utils/activity_launcher.dart';

/// Service for scheduling fun kid-friendly reminder notifications.
///
/// Messages are generated dynamically from activity data and message templates.
/// A sent-index tracker ensures every combination is used before any repeats.
class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  static final Random _random = Random();

  // Notification channel for Android
  static const String _channelId = 'learning_reminders_channel';
  static const String _channelName = 'Learning Reminders';
  static const String _channelDescription =
      'Fun reminders to come back and play!';

  // Preference keys
  static const String _lastScheduledKey = 'notifications_last_scheduled';
  static const String _notificationIdsKey = 'scheduled_notification_ids';
  static const String _enabledKey = 'notifications_enabled';
  static const String _sentIndicesKey = 'notifications_sent_indices';
  static const String _sentPoolSizeKey = 'notifications_sent_pool_size';

  // ---------------------------------------------------------------------------
  // Message generation — templates x activities = large dynamic pool
  // ---------------------------------------------------------------------------

  /// Activities that make sense in notifications (skip calculator — not exciting)
  static const List<String> _notifiableActivities = [
    ActivityIds.storyAdventure,
    ActivityIds.aiChat,
    ActivityIds.aiCall,
    ActivityIds.letterTracing,
    ActivityIds.bubblePop,
    ActivityIds.phonics,
    ActivityIds.mathBuddy,
    ActivityIds.mathChallenge,
    ActivityIds.numberPop,
    ActivityIds.sudoku,
    ActivityIds.memoryMatch,
    ActivityIds.ticTacToe,
    ActivityIds.gobang,
    ActivityIds.chess,
  ];

  /// Emoji per activity for notification titles
  static const Map<String, String> _activityEmoji = {
    ActivityIds.storyAdventure: '📖',
    ActivityIds.aiChat: '🤖',
    ActivityIds.aiCall: '📞',
    ActivityIds.letterTracing: '✏️',
    ActivityIds.bubblePop: '🫧',
    ActivityIds.phonics: '🔤',
    ActivityIds.mathBuddy: '🧮',
    ActivityIds.mathChallenge: '⏱️',
    ActivityIds.numberPop: '🎈',
    ActivityIds.sudoku: '🔢',
    ActivityIds.memoryMatch: '🧠',
    ActivityIds.ticTacToe: '❌',
    ActivityIds.gobang: '⚫',
    ActivityIds.chess: '♟️',
  };

  /// Message templates — {name} is replaced with the activity title.
  /// Each template paired with a title template.
  static const List<_MessageTemplate> _templates = [
    _MessageTemplate(
      title: '{name} misses you! {emoji}',
      body: 'It\'s been a while — come play {name} and have some fun!',
    ),
    _MessageTemplate(
      title: 'Ready for {name}? {emoji}',
      body: 'A new challenge is waiting for you. Let\'s go!',
    ),
    _MessageTemplate(
      title: 'Hey superstar! {emoji}',
      body: 'Time to show off your skills in {name}!',
    ),
    _MessageTemplate(
      title: 'Guess what? {emoji}',
      body: 'Learning Lab has been super quiet without you. Try {name}!',
    ),
    _MessageTemplate(
      title: 'Knock knock! {emoji}',
      body: 'Who\'s there? {name} — ready and waiting for you!',
    ),
    _MessageTemplate(
      title: 'Quick break? {emoji}',
      body: 'Jump into {name} for a fun brain boost!',
    ),
  ];

  /// Build the full message pool: templates x activities.
  /// Returns a list of (title, body) pairs.
  static List<_NotificationContent> _buildMessagePool() {
    final pool = <_NotificationContent>[];
    for (final activityId in _notifiableActivities) {
      final name = activityTitle(activityId);
      final emoji = _activityEmoji[activityId] ?? '🎉';
      for (final template in _templates) {
        pool.add(_NotificationContent(
          title: template.title
              .replaceAll('{name}', name)
              .replaceAll('{emoji}', emoji),
          body: template.body
              .replaceAll('{name}', name)
              .replaceAll('{emoji}', emoji),
        ));
      }
    }
    return pool;
  }

  /// Pick the next unsent message. Resets the tracker when pool is exhausted
  /// or when the pool size changes (e.g. activities/templates were added).
  Future<_NotificationContent> _pickNextMessage() async {
    final pool = _buildMessagePool();
    final prefs = await SharedPreferences.getInstance();
    final savedPoolSize = prefs.getInt(_sentPoolSizeKey) ?? 0;
    var sentIndices =
        (prefs.getStringList(_sentIndicesKey) ?? [])
            .map((s) => int.tryParse(s))
            .whereType<int>()
            .toSet();

    // Reset if pool size changed (activities/templates added/removed)
    // or if we've sent everything
    if (savedPoolSize != pool.length || sentIndices.length >= pool.length) {
      sentIndices = {};
    }

    // Pick a random unsent index
    final available =
        List.generate(pool.length, (i) => i)
            .where((i) => !sentIndices.contains(i))
            .toList();
    final chosen = available[_random.nextInt(available.length)];
    sentIndices.add(chosen);

    await prefs.setInt(_sentPoolSizeKey, pool.length);
    await prefs.setStringList(
      _sentIndicesKey,
      sentIndices.map((i) => i.toString()).toList(),
    );

    return pool[chosen];
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initialize the notification service
  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Android initialization settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'learningReminders',
          actions: <DarwinNotificationAction>[],
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
      ],
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Enable foreground notifications on iOS
    final iOS = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iOS != null) {
      await iOS.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _initialized = true;
    debugPrint('NotificationService initialized');

    // Schedule notifications if enabled
    final enabled = await isEnabled();
    if (enabled) {
      await _scheduleWeeklyNotificationsIfNeeded();
    }
  }

  /// Handle notification tap — just opens the app
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    final iOS = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iOS != null) {
      final granted = await iOS.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Enable / disable toggle (for parental controls)
  // ---------------------------------------------------------------------------

  /// Check if notifications are enabled (defaults to true)
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  /// Enable or disable notifications
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    if (enabled) {
      await requestPermissions();
      await rescheduleNotifications();
    } else {
      await _cancelAllScheduledNotifications();
    }

    debugPrint('Notifications ${enabled ? "enabled" : "disabled"}');
  }

  // ---------------------------------------------------------------------------
  // Scheduling
  // ---------------------------------------------------------------------------

  /// Schedule weekly notifications if not already scheduled this week
  Future<void> _scheduleWeeklyNotificationsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastScheduled = prefs.getInt(_lastScheduledKey) ?? 0;
    final now = DateTime.now();
    final lastScheduledDate =
        DateTime.fromMillisecondsSinceEpoch(lastScheduled);

    // Check if we need to reschedule (different week)
    final needsReschedule = _isDifferentWeek(lastScheduledDate, now);

    if (needsReschedule) {
      await _cancelAllScheduledNotifications();
      final scheduled = await _scheduleWeeklyNotifications();
      // Only mark week as done if we actually scheduled notifications.
      // If 0 were scheduled (e.g. Sunday night), we'll retry next app open.
      if (scheduled > 0) {
        await prefs.setInt(_lastScheduledKey, now.millisecondsSinceEpoch);
      }
    }
  }

  /// Check if two dates are in different weeks
  bool _isDifferentWeek(DateTime date1, DateTime date2) {
    final monday1 = date1.subtract(Duration(days: date1.weekday - 1));
    final monday2 = date2.subtract(Duration(days: date2.weekday - 1));

    return monday1.year != monday2.year ||
        monday1.month != monday2.month ||
        monday1.day != monday2.day;
  }

  /// Schedule 2 notifications for the current week.
  /// Returns the number of notifications actually scheduled.
  Future<int> _scheduleWeeklyNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final scheduledIds = <int>[];

    const notificationCount = 2;

    // Pick random days this week (excluding today if it's late)
    final availableDays = _getAvailableDaysThisWeek(now);

    if (availableDays.isEmpty) return 0;

    // Shuffle and pick days
    availableDays.shuffle(_random);
    final selectedDays = availableDays.take(notificationCount).toList();

    for (int i = 0; i < selectedDays.length; i++) {
      final day = selectedDays[i];
      final message = await _pickNextMessage();

      // Schedule for afternoon (random time between 4-6 PM)
      final hour = 16 + _random.nextInt(2); // 16 or 17 (4 PM or 5 PM)
      final minute = _random.nextInt(60);

      final scheduledDate = DateTime(
        day.year,
        day.month,
        day.day,
        hour,
        minute,
      );

      // Only schedule if in the future
      if (scheduledDate.isAfter(now)) {
        final notificationId = _generateNotificationId(i, day);
        scheduledIds.add(notificationId);

        await _scheduleNotification(
          id: notificationId,
          title: message.title,
          body: message.body,
          scheduledDate: scheduledDate,
        );
      }
    }

    // Save scheduled notification IDs for later cancellation
    await prefs.setStringList(
      _notificationIdsKey,
      scheduledIds.map((id) => id.toString()).toList(),
    );

    debugPrint('Scheduled ${scheduledIds.length} weekly notifications '
        '(pool size: ${_buildMessagePool().length})');

    return scheduledIds.length;
  }

  /// Get available days this week for notifications
  List<DateTime> _getAvailableDaysThisWeek(DateTime now) {
    final days = <DateTime>[];
    final currentWeekday = now.weekday;

    // Add remaining days this week
    for (int i = currentWeekday; i <= 7; i++) {
      final day = now.add(Duration(days: i - currentWeekday));

      // Skip today if it's already past 6 PM
      if (i == currentWeekday && now.hour >= 18) continue;

      days.add(DateTime(day.year, day.month, day.day));
    }

    return days;
  }

  /// Generate a unique notification ID from date components.
  /// Uses dayOfYear * 100 + year-offset * 40000 + index to avoid collisions
  /// across years and same-day scheduling.
  int _generateNotificationId(int index, DateTime day) {
    final dayOfYear =
        day.difference(DateTime(day.year, 1, 1)).inDays + 1; // 1-366
    final yearOffset = day.year - 2024; // keeps numbers small
    return yearOffset * 40000 + dayOfYear * 100 + index;
  }

  /// Schedule a single notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }

  /// Cancel all scheduled notifications
  Future<void> _cancelAllScheduledNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_notificationIdsKey) ?? [];

    for (final idStr in ids) {
      final id = int.tryParse(idStr);
      if (id != null) {
        await _notifications.cancel(id);
      }
    }

    await prefs.setStringList(_notificationIdsKey, []);
  }

  /// Force reschedule notifications
  Future<void> rescheduleNotifications() async {
    await _cancelAllScheduledNotifications();
    await _scheduleWeeklyNotifications();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _lastScheduledKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Check if notifications are pending
  Future<bool> hasPendingNotifications() async {
    final pending = await _notifications.pendingNotificationRequests();
    return pending.isNotEmpty;
  }

  /// Get list of pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // ---------------------------------------------------------------------------
  // Debug / testing methods
  // ---------------------------------------------------------------------------

  /// Send a test notification immediately
  Future<String?> sendTestNotification() async {
    final message = await _pickNextMessage();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      styleInformation: BigTextStyleInformation(message.body),
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      9999,
      message.title,
      message.body,
      details,
    );

    return '${message.title}\n\n${message.body}';
  }

  /// Schedule a test notification for 10 seconds from now
  Future<void> scheduleTestNotification() async {
    final message = await _pickNextMessage();
    final scheduledDate = DateTime.now().add(const Duration(seconds: 10));

    await _scheduleNotification(
      id: 9998,
      title: message.title,
      body: message.body,
      scheduledDate: scheduledDate,
    );
  }
}

/// Message template with {name} and {emoji} placeholders
class _MessageTemplate {
  final String title;
  final String body;

  const _MessageTemplate({required this.title, required this.body});
}

/// Resolved notification content
class _NotificationContent {
  final String title;
  final String body;

  const _NotificationContent({required this.title, required this.body});
}
