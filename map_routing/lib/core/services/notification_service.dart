import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:map_routing/data/models/planned_workout.dart';
import 'package:map_routing/data/services/app_settings_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const _chatChannelId = 'chat_messages_channel';
  static const _workoutChannelId = 'workout_reminders_channel';
  static const _startWorkoutActionId = 'start_planned_workout';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timeZonesReady = false;

  void Function(String payload)? onPayloadTap;

  Future<void> init() async {
    if (_initialized) return;

    await AppSettingsService.instance.ensureLoaded();
    await _ensureTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    const chatChannel = AndroidNotificationChannel(
      _chatChannelId,
      'Сообщения чатов',
      description: 'Уведомления о новых сообщениях и заявках',
      importance: Importance.high,
    );
    const workoutChannel = AndroidNotificationChannel(
      _workoutChannelId,
      'Тренировки',
      description: 'Напоминания о запланированных тренировках',
      importance: Importance.high,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(chatChannel);
    await androidPlugin?.createNotificationChannel(workoutChannel);
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> _ensureTimeZones() async {
    if (_timeZonesReady) return;
    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }
    _timeZonesReady = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    onPayloadTap?.call(payload);
  }

  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    await AppSettingsService.instance.ensureLoaded();
    if (!AppSettingsService.instance.pushNotificationsEnabled) {
      return;
    }

    if (!_initialized) {
      await init();
    }

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _chatChannelId,
        'Сообщения чатов',
        channelDescription: 'Уведомления о новых сообщениях и заявках',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    try {
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Notification error: $e');
      }
    }
  }

  Future<void> schedulePlannedWorkout(PlannedWorkout workout) async {
    await AppSettingsService.instance.ensureLoaded();
    if (!AppSettingsService.instance.pushNotificationsEnabled) {
      return;
    }

    if (!_initialized) {
      await init();
    }

    if (!workout.scheduledAt.isAfter(DateTime.now())) {
      await cancelScheduled(workout.notificationId);
      return;
    }

    final scheduled = tz.TZDateTime.from(workout.scheduledAt, tz.local);
    final distanceKm = (workout.distanceMeters / 1000).toStringAsFixed(1);
    final body =
        '${workout.activityType.labelRu} · $distanceKm км · ~${workout.estimatedCalories} ккал';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _workoutChannelId,
        'Тренировки',
        channelDescription: 'Напоминания о запланированных тренировках',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            _startWorkoutActionId,
            'Начать тренировку',
            showsUserInterface: true,
          ),
        ],
      ),
    );

    try {
      await _plugin.zonedSchedule(
        workout.notificationId,
        'Запланированная тренировка',
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'planned_workout:${workout.id}',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Schedule notification error: $e');
      }
    }
  }

  Future<void> cancelScheduled(int notificationId) async {
    if (!_initialized) return;
    await _plugin.cancel(notificationId);
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }
}
