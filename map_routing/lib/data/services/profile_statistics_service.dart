import 'dart:math' as math;

import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/models/workout_summary.dart';
import 'package:map_routing/data/services/workout_analytics.dart';

enum ProfileStatMetric {
  workouts('Тренировки', 'шт.'),
  distance('Дистанция', 'км'),
  duration('Время', 'ч'),
  elevation('Набор высоты', 'м'),
  calories('Калории', 'ккал');

  const ProfileStatMetric(this.title, this.unit);

  final String title;
  final String unit;
}

enum ProfileStatPeriod {
  week('Неделя'),
  month('Месяц'),
  year('Год'),
  allTime('Всё время');

  const ProfileStatPeriod(this.label);

  final String label;
}

class ProfileTotals {
  const ProfileTotals({
    required this.workoutCount,
    required this.totalDistanceM,
    required this.totalDuration,
    required this.totalElevationM,
    required this.totalCalories,
    required this.activeDays,
    this.avgPaceMinPerKm,
    required this.avgWorkoutDuration,
  });

  final int workoutCount;
  final double totalDistanceM;
  final Duration totalDuration;
  final double totalElevationM;
  final int totalCalories;
  final int activeDays;
  final double? avgPaceMinPerKm;
  final Duration avgWorkoutDuration;

  static const empty = ProfileTotals(
    workoutCount: 0,
    totalDistanceM: 0,
    totalDuration: Duration.zero,
    totalElevationM: 0,
    totalCalories: 0,
    activeDays: 0,
    avgWorkoutDuration: Duration.zero,
  );
}

class ProfilePeriodSnapshot {
  const ProfilePeriodSnapshot({
    required this.workoutCount,
    required this.distanceM,
    required this.duration,
    required this.elevationM,
    required this.calories,
  });

  final int workoutCount;
  final double distanceM;
  final Duration duration;
  final double elevationM;
  final int calories;
}

class ProfilePeriodComparison {
  const ProfilePeriodComparison({
    required this.currentLabel,
    required this.previousLabel,
    required this.current,
    required this.previous,
  });

  final String currentLabel;
  final String previousLabel;
  final ProfilePeriodSnapshot current;
  final ProfilePeriodSnapshot previous;

  double? changePercent(double current, double previous) {
    if (previous <= 0) return current > 0 ? 100 : null;
    return ((current - previous) / previous) * 100;
  }

  double? get distanceChangePercent =>
      changePercent(current.distanceM, previous.distanceM);

  double? get workoutsChangePercent => changePercent(
        current.workoutCount.toDouble(),
        previous.workoutCount.toDouble(),
      );

  double? get durationChangePercent => changePercent(
        current.duration.inSeconds.toDouble(),
        previous.duration.inSeconds.toDouble(),
      );

  double? get caloriesChangePercent =>
      changePercent(current.calories.toDouble(), previous.calories.toDouble());
}

class ProfileRegularityStats {
  const ProfileRegularityStats({
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.activeDaysThisMonth,
    required this.daysInCurrentMonth,
    required this.currentMonthLabel,
    required this.avgKmPerWeekThisMonth,
  });

  final int currentStreakDays;
  final int longestStreakDays;
  final int activeDaysThisMonth;
  final int daysInCurrentMonth;
  final String currentMonthLabel;
  final double avgKmPerWeekThisMonth;
}

class ActivityHeatmapDay {
  const ActivityHeatmapDay({
    required this.date,
    required this.distanceM,
    required this.workoutCount,
  });

  final DateTime date;
  final double distanceM;
  final int workoutCount;

  double get distanceKm => distanceM / 1000;
}

class ActivityTypeShare {
  const ActivityTypeShare({
    required this.activity,
    required this.distanceM,
    required this.workoutCount,
    required this.percent,
  });

  final WorkoutActivityType activity;
  final double distanceM;
  final int workoutCount;
  final double percent;
}

class ProfileActivityPatterns {
  const ProfileActivityPatterns({
    required this.distanceByWeekday,
    required this.workoutsByTimeBucket,
    required this.activityShares,
  });

  final List<double> distanceByWeekday;
  final List<int> workoutsByTimeBucket;
  final List<ActivityTypeShare> activityShares;

  static const weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const timeBucketLabels = ['Утро', 'День', 'Вечер', 'Ночь'];
}

class StatTrendPoint {
  const StatTrendPoint({
    required this.label,
    required this.value,
    this.date,
  });

  final String label;
  final double value;
  final DateTime? date;
}

class DistanceRecord {
  const DistanceRecord({
    required this.label,
    required this.targetMeters,
    this.bestDuration,
    this.workout,
  });

  final String label;
  final double targetMeters;
  final Duration? bestDuration;
  final WorkoutSummary? workout;
}

class ProfilePersonalRecords {
  const ProfilePersonalRecords({
    this.longestWorkout,
    this.longestDurationWorkout,
    this.bestPaceWorkout,
    this.bestPaceMinPerKm,
    this.bestWeekDistanceKm = 0,
    this.bestWeekLabel,
    this.bestMonthDistanceKm = 0,
    this.bestMonthLabel,
    this.biggestClimbWorkout,
    this.biggestClimbM = 0,
    this.sustainedAscentWorkout,
    this.sustainedAscentM = 0,
    this.fastest5k,
    this.fastest10k,
    this.fastestHalfMarathon,
    this.fastestMarathon,
    this.fastest5kWorkout,
    this.fastest10kWorkout,
    this.fastestHalfWorkout,
    this.fastestMarathonWorkout,
  });

  final WorkoutSummary? longestWorkout;
  final WorkoutSummary? longestDurationWorkout;
  final WorkoutSummary? bestPaceWorkout;
  final double? bestPaceMinPerKm;
  final double bestWeekDistanceKm;
  final String? bestWeekLabel;
  final double bestMonthDistanceKm;
  final String? bestMonthLabel;
  final WorkoutSummary? biggestClimbWorkout;
  final double biggestClimbM;
  final WorkoutSummary? sustainedAscentWorkout;
  final double sustainedAscentM;
  final Duration? fastest5k;
  final Duration? fastest10k;
  final Duration? fastestHalfMarathon;
  final Duration? fastestMarathon;
  final WorkoutSummary? fastest5kWorkout;
  final WorkoutSummary? fastest10kWorkout;
  final WorkoutSummary? fastestHalfWorkout;
  final WorkoutSummary? fastestMarathonWorkout;

  List<DistanceRecord> get distanceRecords => [
        DistanceRecord(
          label: '5 км',
          targetMeters: 5000,
          bestDuration: fastest5k,
          workout: fastest5kWorkout,
        ),
        DistanceRecord(
          label: '10 км',
          targetMeters: 10000,
          bestDuration: fastest10k,
          workout: fastest10kWorkout,
        ),
        DistanceRecord(
          label: 'Полумарафон',
          targetMeters: 21097.5,
          bestDuration: fastestHalfMarathon,
          workout: fastestHalfWorkout,
        ),
        DistanceRecord(
          label: 'Марафон',
          targetMeters: 42195,
          bestDuration: fastestMarathon,
          workout: fastestMarathonWorkout,
        ),
      ];
}

class RollingWeekSnapshot {
  const RollingWeekSnapshot({
    required this.dailyDistanceMeters,
    required this.weekDistanceKm,
    required this.weekOverWeekChangePercent,
  });

  final List<double> dailyDistanceMeters;
  final double weekDistanceKm;
  final double? weekOverWeekChangePercent;
}

abstract final class ProfileStatisticsService {
  static const _halfMarathonM = 21097.5;
  static const _marathonM = 42195.0;

  static List<WorkoutSummary> filterByActivity(
    List<WorkoutSummary> workouts,
    WorkoutActivityType? activity,
  ) {
    if (activity == null) return workouts;
    return workouts
        .where((w) => (w.activityType ?? WorkoutActivityType.run) == activity)
        .toList();
  }

  static List<WorkoutSummary> filterOwnWorkouts(
    List<WorkoutSummary> workouts,
  ) =>
      workouts.where((workout) => !workout.isImported).toList(growable: false);

  /// Скользящие 7 дней (сегодня и 6 предыдущих) — как на графике профиля.
  static RollingWeekSnapshot computeRollingSevenDaySnapshot(
    List<WorkoutSummary> workouts, {
    DateTime? reference,
  }) {
    final now = reference ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final windowStart = today.subtract(const Duration(days: 6));

    final daily = List<double>.filled(7, 0);
    var currentWeekM = 0.0;
    var previousWeekM = 0.0;

    for (final workout in workouts) {
      final startedAt = workout.startedAt;
      if (startedAt == null) continue;

      final day = DateTime(
        startedAt.year,
        startedAt.month,
        startedAt.day,
      );
      final daysAgo = today.difference(day).inDays;
      final distanceMeters = workout.distanceMeters;

      if (daysAgo >= 0 && daysAgo < 7) {
        final index = day.difference(windowStart).inDays;
        if (index >= 0 && index < 7) {
          daily[index] += distanceMeters;
        }
        currentWeekM += distanceMeters;
      } else if (daysAgo >= 7 && daysAgo < 14) {
        previousWeekM += distanceMeters;
      }
    }

    double? weekOverWeekChangePercent;
    if (previousWeekM <= 0) {
      weekOverWeekChangePercent = currentWeekM > 0 ? 100.0 : null;
    } else {
      weekOverWeekChangePercent =
          ((currentWeekM - previousWeekM) / previousWeekM) * 100;
    }

    return RollingWeekSnapshot(
      dailyDistanceMeters: daily,
      weekDistanceKm: currentWeekM / 1000.0,
      weekOverWeekChangePercent: weekOverWeekChangePercent,
    );
  }

  static ProfileTotals computeTotals(List<WorkoutSummary> workouts) {
    if (workouts.isEmpty) return ProfileTotals.empty;

    var totalDist = 0.0;
    var totalElev = 0.0;
    var totalSeconds = 0;
    var totalCalories = 0;
    var paceWeighted = 0.0;
    var paceDistance = 0.0;
    final activeDayKeys = <String>{};

    for (final w in workouts) {
      totalDist += w.distanceMeters;
      totalElev += _workoutElevation(w);
      totalSeconds += w.duration?.inSeconds ?? 0;
      totalCalories += w.calories ?? 0;

      final startedAt = w.startedAt;
      if (startedAt != null) {
        activeDayKeys.add(
          '${startedAt.year}-${startedAt.month}-${startedAt.day}',
        );
      }

      final pace = _workoutPaceMinPerKm(w);
      if (pace != null && w.distanceMeters >= 1000) {
        paceWeighted += pace * w.distanceMeters;
        paceDistance += w.distanceMeters;
      }
    }

    final avgWorkoutDuration = workouts.isEmpty
        ? Duration.zero
        : Duration(seconds: totalSeconds ~/ workouts.length);

    return ProfileTotals(
      workoutCount: workouts.length,
      totalDistanceM: totalDist,
      totalDuration: Duration(seconds: totalSeconds),
      totalElevationM: totalElev,
      totalCalories: totalCalories,
      activeDays: activeDayKeys.length,
      avgPaceMinPerKm:
          paceDistance > 0 ? paceWeighted / paceDistance : null,
      avgWorkoutDuration: avgWorkoutDuration,
    );
  }

  static ProfilePeriodComparison computeMonthComparison(
    List<WorkoutSummary> workouts, {
    DateTime? reference,
  }) {
    final now = reference ?? DateTime.now();
    final thisMonthStart = startOfMonth(now);
    final nextMonthStart = _subtractMonths(thisMonthStart, -1);
    final prevMonthStart = _subtractMonths(thisMonthStart, 1);

    const monthNames = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];

    return ProfilePeriodComparison(
      currentLabel: '${monthNames[thisMonthStart.month - 1]} ${thisMonthStart.year}',
      previousLabel:
          '${monthNames[prevMonthStart.month - 1]} ${prevMonthStart.year}',
      current: _snapshotForRange(workouts, thisMonthStart, nextMonthStart),
      previous: _snapshotForRange(workouts, prevMonthStart, thisMonthStart),
    );
  }

  static ProfilePeriodComparison computeWeekComparison(
    List<WorkoutSummary> workouts, {
    DateTime? reference,
  }) {
    final now = reference ?? DateTime.now();
    final thisWeekStart = startOfWeek(now);
    final nextWeekStart = thisWeekStart.add(const Duration(days: 7));
    final prevWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    return ProfilePeriodComparison(
      currentLabel: 'Эта неделя',
      previousLabel: 'Прошлая неделя',
      current: _snapshotForRange(workouts, thisWeekStart, nextWeekStart),
      previous: _snapshotForRange(workouts, prevWeekStart, thisWeekStart),
    );
  }

  static ProfileRegularityStats computeRegularity(
    List<WorkoutSummary> workouts, {
    DateTime? reference,
  }) {
    final now = reference ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeDays = <DateTime>{};

    for (final workout in workouts) {
      final startedAt = workout.startedAt;
      if (startedAt == null) continue;
      activeDays.add(DateTime(startedAt.year, startedAt.month, startedAt.day));
    }

    var currentStreak = 0;
    var cursor = today;
    while (activeDays.contains(cursor)) {
      currentStreak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var longestStreak = 0;
    if (activeDays.isNotEmpty) {
      final sorted = activeDays.toList()..sort();
      var run = 1;
      longestStreak = 1;
      for (var i = 1; i < sorted.length; i++) {
        if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
          run++;
          longestStreak = math.max(longestStreak, run);
        } else {
          run = 1;
        }
      }
    }

    const monthNames = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    final monthStart = DateTime(today.year, today.month, 1);
    final daysInCurrentMonth = DateTime(today.year, today.month + 1, 0).day;
    var activeThisMonth = 0;
    var distanceThisMonth = 0.0;
    for (final day in activeDays) {
      if (!day.isBefore(monthStart) && !day.isAfter(today)) {
        activeThisMonth++;
      }
    }
    for (final workout in workouts) {
      final startedAt = workout.startedAt;
      if (startedAt == null) continue;
      final day = DateTime(startedAt.year, startedAt.month, startedAt.day);
      if (!day.isBefore(monthStart) && !day.isAfter(today)) {
        distanceThisMonth += workout.distanceMeters;
      }
    }

    final weeksElapsed = (today.day / 7).clamp(1.0, daysInCurrentMonth / 7.0);

    return ProfileRegularityStats(
      currentStreakDays: currentStreak,
      longestStreakDays: longestStreak,
      activeDaysThisMonth: activeThisMonth,
      daysInCurrentMonth: daysInCurrentMonth,
      currentMonthLabel: monthNames[today.month - 1],
      avgKmPerWeekThisMonth: distanceThisMonth / 1000 / weeksElapsed,
    );
  }

  static List<ActivityHeatmapDay> buildActivityHeatmap(
    List<WorkoutSummary> workouts, {
    int weeks = 12,
    DateTime? reference,
  }) {
    final now = reference ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: weeks * 7 - 1));

    final distanceByDay = <DateTime, double>{};
    final countByDay = <DateTime, int>{};

    for (final workout in workouts) {
      final startedAt = workout.startedAt;
      if (startedAt == null) continue;
      final day = DateTime(startedAt.year, startedAt.month, startedAt.day);
      if (day.isBefore(start)) continue;
      distanceByDay[day] = (distanceByDay[day] ?? 0) + workout.distanceMeters;
      countByDay[day] = (countByDay[day] ?? 0) + 1;
    }

    final days = <ActivityHeatmapDay>[];
    for (var i = 0; i < weeks * 7; i++) {
      final day = start.add(Duration(days: i));
      days.add(
        ActivityHeatmapDay(
          date: day,
          distanceM: distanceByDay[day] ?? 0,
          workoutCount: countByDay[day] ?? 0,
        ),
      );
    }
    return days;
  }

  static ProfileActivityPatterns computeActivityPatterns(
    List<WorkoutSummary> workouts,
  ) {
    final distanceByWeekday = List<double>.filled(7, 0);
    final workoutsByTimeBucket = List<int>.filled(4, 0);
    final distanceByActivity = <WorkoutActivityType, double>{};
    final countByActivity = <WorkoutActivityType, int>{};
    var totalDistance = 0.0;

    for (final workout in workouts) {
      final startedAt = workout.startedAt;
      if (startedAt != null) {
        distanceByWeekday[startedAt.weekday - 1] += workout.distanceMeters;
        workoutsByTimeBucket[_timeBucketIndex(startedAt.hour)]++;
      }

      final activity = workout.activityType ?? WorkoutActivityType.run;
      distanceByActivity[activity] =
          (distanceByActivity[activity] ?? 0) + workout.distanceMeters;
      countByActivity[activity] = (countByActivity[activity] ?? 0) + 1;
      totalDistance += workout.distanceMeters;
    }

    final shares = distanceByActivity.entries.map((entry) {
      return ActivityTypeShare(
        activity: entry.key,
        distanceM: entry.value,
        workoutCount: countByActivity[entry.key] ?? 0,
        percent: totalDistance > 0 ? (entry.value / totalDistance) * 100 : 0,
      );
    }).toList()
      ..sort((a, b) => b.distanceM.compareTo(a.distanceM));

    return ProfileActivityPatterns(
      distanceByWeekday: distanceByWeekday,
      workoutsByTimeBucket: workoutsByTimeBucket,
      activityShares: shares,
    );
  }

  static String formatChangePercent(double? value) {
    if (value == null) return '—';
    final sign = value > 0 ? '+' : '';
    return '$sign${value.round()}%';
  }

  static String formatPaceMinPerKm(double? minutes) {
    if (minutes == null || minutes <= 0 || !minutes.isFinite) return '—';
    final totalSeconds = (minutes * 60).round();
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return "$m'${s.toString().padLeft(2, '0')}'' / км";
  }

  static ProfilePeriodSnapshot _snapshotForRange(
    List<WorkoutSummary> workouts,
    DateTime start,
    DateTime end,
  ) {
    var distance = 0.0;
    var elevation = 0.0;
    var seconds = 0;
    var calories = 0;
    var count = 0;

    for (final workout in workouts) {
      final startedAt = workout.startedAt;
      if (startedAt == null) continue;
      if (startedAt.isBefore(start) || !startedAt.isBefore(end)) continue;
      count++;
      distance += workout.distanceMeters;
      elevation += _workoutElevation(workout);
      seconds += workout.duration?.inSeconds ?? 0;
      calories += workout.calories ?? 0;
    }

    return ProfilePeriodSnapshot(
      workoutCount: count,
      distanceM: distance,
      duration: Duration(seconds: seconds),
      elevationM: elevation,
      calories: calories,
    );
  }

  static int _timeBucketIndex(int hour) {
    if (hour >= 6 && hour < 12) return 0;
    if (hour >= 12 && hour < 18) return 1;
    if (hour >= 18 && hour < 22) return 2;
    return 3;
  }

  static double? _workoutPaceMinPerKm(WorkoutSummary workout) {
    final duration = workout.duration;
    if (duration == null || duration.inSeconds <= 0) return null;
    if (workout.distanceMeters < 100) return null;
    return duration.inSeconds / 60 / (workout.distanceMeters / 1000);
  }

  static List<StatTrendPoint> buildTrend({
    required List<WorkoutSummary> workouts,
    required ProfileStatMetric metric,
    required ProfileStatPeriod period,
    DateTime? anchor,
  }) {
    final reference = anchor ?? DateTime.now();
    final dated = workouts
        .where((w) => w.startedAt != null)
        .toList()
      ..sort((a, b) => a.startedAt!.compareTo(b.startedAt!));

    if (dated.isEmpty) return [];

    switch (period) {
      case ProfileStatPeriod.week:
        return _calendarWeekTrend(
          workouts: dated,
          metric: metric,
          anchor: reference,
        );
      case ProfileStatPeriod.month:
        return _calendarMonthDailyTrend(
          workouts: dated,
          metric: metric,
          anchor: reference,
        );
      case ProfileStatPeriod.year:
        return _calendarYearMonthlyTrend(
          workouts: dated,
          metric: metric,
          anchor: reference,
        );
      case ProfileStatPeriod.allTime:
        return _allTimeTrend(workouts: dated, metric: metric);
    }
  }

  static DateTime startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime startOfYear(DateTime date) => DateTime(date.year, 1, 1);

  static DateTime shiftAnchor(ProfileStatPeriod period, DateTime anchor, int delta) {
    switch (period) {
      case ProfileStatPeriod.week:
        return anchor.add(Duration(days: 7 * delta));
      case ProfileStatPeriod.month:
        return _subtractMonths(startOfMonth(anchor), -delta);
      case ProfileStatPeriod.year:
        return DateTime(anchor.year + delta, anchor.month, anchor.day);
      case ProfileStatPeriod.allTime:
        return anchor;
    }
  }

  static String formatAnchorLabel(ProfileStatPeriod period, DateTime anchor) {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    switch (period) {
      case ProfileStatPeriod.week:
        final start = startOfWeek(anchor);
        final end = start.add(const Duration(days: 6));
        if (start.month == end.month) {
          return '${start.day}–${end.day} ${months[start.month - 1]} ${start.year}';
        }
        return '${start.day}.${start.month} – ${end.day}.${end.month}.${end.year}';
      case ProfileStatPeriod.month:
        const monthNames = [
          'Январь',
          'Февраль',
          'Март',
          'Апрель',
          'Май',
          'Июнь',
          'Июль',
          'Август',
          'Сентябрь',
          'Октябрь',
          'Ноябрь',
          'Декабрь',
        ];
        return '${monthNames[anchor.month - 1]} ${anchor.year}';
      case ProfileStatPeriod.year:
        return '${anchor.year}';
      case ProfileStatPeriod.allTime:
        return 'Всё время';
    }
  }

  static DateTime? earliestWorkoutDate(List<WorkoutSummary> workouts) {
    final dates = workouts.map((w) => w.startedAt).whereType<DateTime>().toList();
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first;
  }

  static DateTime? latestWorkoutDate(List<WorkoutSummary> workouts) {
    final dates = workouts.map((w) => w.startedAt).whereType<DateTime>().toList();
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.last;
  }

  static bool canShiftAnchor({
    required ProfileStatPeriod period,
    required DateTime anchor,
    required int delta,
    required List<WorkoutSummary> workouts,
  }) {
    if (period == ProfileStatPeriod.allTime || delta == 0) {
      return period != ProfileStatPeriod.allTime || delta == 0;
    }
    final next = shiftAnchor(period, anchor, delta);
    final earliest = earliestWorkoutDate(workouts);
    final latest = latestWorkoutDate(workouts);
    if (earliest == null || latest == null) return false;

    if (delta < 0) {
      switch (period) {
        case ProfileStatPeriod.week:
          return !startOfWeek(next).isBefore(startOfWeek(earliest));
        case ProfileStatPeriod.month:
          return !startOfMonth(next).isBefore(startOfMonth(earliest));
        case ProfileStatPeriod.year:
          return next.year >= earliest.year;
        case ProfileStatPeriod.allTime:
          return false;
      }
    } else {
      final now = DateTime.now();
      switch (period) {
        case ProfileStatPeriod.week:
          return !startOfWeek(next).isAfter(startOfWeek(now));
        case ProfileStatPeriod.month:
          return !startOfMonth(next).isAfter(startOfMonth(now));
        case ProfileStatPeriod.year:
          return next.year <= now.year;
        case ProfileStatPeriod.allTime:
          return false;
      }
    }
  }

  static List<StatTrendPoint> _calendarWeekTrend({
    required List<WorkoutSummary> workouts,
    required ProfileStatMetric metric,
    required DateTime anchor,
  }) {
    const dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final weekStart = startOfWeek(anchor);
    final points = <StatTrendPoint>[];

    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      final dayWorkouts = workouts.where((w) {
        final d = w.startedAt!;
        return !d.isBefore(day) && d.isBefore(nextDay);
      }).toList();

      points.add(
        StatTrendPoint(
          label: dayNames[i],
          value: _metricValue(dayWorkouts, metric),
          date: day,
        ),
      );
    }
    return points;
  }

  static List<StatTrendPoint> _calendarMonthDailyTrend({
    required List<WorkoutSummary> workouts,
    required ProfileStatMetric metric,
    required DateTime anchor,
  }) {
    final monthStart = startOfMonth(anchor);
    final monthEnd = _subtractMonths(monthStart, -1);
    final daysInMonth = monthEnd.difference(monthStart).inDays;
    final points = <StatTrendPoint>[];

    for (var i = 0; i < daysInMonth; i++) {
      final day = monthStart.add(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      final dayWorkouts = workouts.where((w) {
        final d = w.startedAt!;
        return !d.isBefore(day) && d.isBefore(nextDay);
      }).toList();

      points.add(
        StatTrendPoint(
          label: '${day.day}',
          value: _metricValue(dayWorkouts, metric),
          date: day,
        ),
      );
    }
    return points;
  }

  static List<StatTrendPoint> _calendarYearMonthlyTrend({
    required List<WorkoutSummary> workouts,
    required ProfileStatMetric metric,
    required DateTime anchor,
  }) {
    const monthNames = [
      'Янв',
      'Фев',
      'Мар',
      'Апр',
      'Май',
      'Июн',
      'Июл',
      'Авг',
      'Сен',
      'Окт',
      'Ноя',
      'Дек',
    ];
    final points = <StatTrendPoint>[];

    for (var month = 1; month <= 12; month++) {
      final monthStart = DateTime(anchor.year, month, 1);
      final monthEnd = _subtractMonths(monthStart, -1);
      final monthWorkouts = workouts.where((w) {
        final d = w.startedAt!;
        return !d.isBefore(monthStart) && d.isBefore(monthEnd);
      }).toList();

      points.add(
        StatTrendPoint(
          label: monthNames[month - 1],
          value: _metricValue(monthWorkouts, metric),
          date: monthStart,
        ),
      );
    }
    return points;
  }

  static ProfilePersonalRecords computeRecords(List<WorkoutSummary> workouts) {
    if (workouts.isEmpty) return const ProfilePersonalRecords();

    WorkoutSummary? longest;
    WorkoutSummary? longestDuration;
    WorkoutSummary? bestPaceWorkout;
    var bestPace = double.infinity;
    WorkoutSummary? biggestClimb;
    var biggestClimbM = 0.0;
    WorkoutSummary? sustainedWorkout;
    var sustainedM = 0.0;

    Duration? best5k;
    Duration? best10k;
    Duration? bestHalf;
    Duration? bestMarathon;
    WorkoutSummary? w5k;
    WorkoutSummary? w10k;
    WorkoutSummary? wHalf;
    WorkoutSummary? wMarathon;

    for (final workout in workouts) {
      if (longest == null ||
          workout.distanceMeters > longest.distanceMeters) {
        longest = workout;
      }

      final duration = workout.duration;
      if (duration != null &&
          duration.inSeconds > 0 &&
          (longestDuration?.duration?.inSeconds ?? 0) < duration.inSeconds) {
        longestDuration = workout;
      }

      if (workout.distanceMeters >= 3000) {
        final pace = _workoutPaceMinPerKm(workout);
        if (pace != null && pace < bestPace) {
          bestPace = pace;
          bestPaceWorkout = workout;
        }
      }

      final climb = _workoutElevation(workout);
      if (climb > biggestClimbM) {
        biggestClimbM = climb;
        biggestClimb = workout;
      }

      final sustained = longestMonotonicAscent(workout.points);
      if (sustained > sustainedM) {
        sustainedM = sustained;
        sustainedWorkout = workout;
      }

      _updateBestSplit(
        workout: workout,
        targetM: 5000,
        current: best5k,
        onBetter: (d) {
          best5k = d;
          w5k = workout;
        },
      );
      _updateBestSplit(
        workout: workout,
        targetM: 10000,
        current: best10k,
        onBetter: (d) {
          best10k = d;
          w10k = workout;
        },
      );
      _updateBestSplit(
        workout: workout,
        targetM: _halfMarathonM,
        current: bestHalf,
        onBetter: (d) {
          bestHalf = d;
          wHalf = workout;
        },
      );
      _updateBestSplit(
        workout: workout,
        targetM: _marathonM,
        current: bestMarathon,
        onBetter: (d) {
          bestMarathon = d;
          wMarathon = workout;
        },
      );
    }

    final bestWeek = _bestWeekDistance(workouts);
    final bestMonth = _bestMonthDistance(workouts);

    return ProfilePersonalRecords(
      longestWorkout: longest,
      longestDurationWorkout: longestDuration,
      bestPaceWorkout: bestPaceWorkout,
      bestPaceMinPerKm: bestPace.isFinite ? bestPace : null,
      bestWeekDistanceKm: bestWeek.$1,
      bestWeekLabel: bestWeek.$2,
      bestMonthDistanceKm: bestMonth.$1,
      bestMonthLabel: bestMonth.$2,
      biggestClimbWorkout: biggestClimb,
      biggestClimbM: biggestClimbM,
      sustainedAscentWorkout: sustainedWorkout,
      sustainedAscentM: sustainedM,
      fastest5k: best5k,
      fastest10k: best10k,
      fastestHalfMarathon: bestHalf,
      fastestMarathon: bestMarathon,
      fastest5kWorkout: w5k,
      fastest10kWorkout: w10k,
      fastestHalfWorkout: wHalf,
      fastestMarathonWorkout: wMarathon,
    );
  }

  static (double, String?) _bestWeekDistance(List<WorkoutSummary> workouts) {
    final weekly = <DateTime, double>{};
    for (final workout in workouts) {
      final startedAt = workout.startedAt;
      if (startedAt == null) continue;
      final weekStart = startOfWeek(startedAt);
      weekly[weekStart] = (weekly[weekStart] ?? 0) + workout.distanceMeters;
    }
    if (weekly.isEmpty) return (0, null);

    DateTime? bestWeek;
    var bestKm = 0.0;
    weekly.forEach((week, meters) {
      if (meters > bestKm) {
        bestKm = meters;
        bestWeek = week;
      }
    });

    if (bestWeek == null) return (0, null);
    final end = bestWeek!.add(const Duration(days: 6));
    return (
      bestKm / 1000,
      '${bestWeek!.day}.${bestWeek!.month}–${end.day}.${end.month}',
    );
  }

  static (double, String?) _bestMonthDistance(List<WorkoutSummary> workouts) {
    final monthly = <DateTime, double>{};
    const monthNames = [
      'Янв',
      'Фев',
      'Мар',
      'Апр',
      'Май',
      'Июн',
      'Июл',
      'Авг',
      'Сен',
      'Окт',
      'Ноя',
      'Дек',
    ];

    for (final workout in workouts) {
      final startedAt = workout.startedAt;
      if (startedAt == null) continue;
      final monthStart = startOfMonth(startedAt);
      monthly[monthStart] = (monthly[monthStart] ?? 0) + workout.distanceMeters;
    }
    if (monthly.isEmpty) return (0, null);

    DateTime? bestMonth;
    var bestKm = 0.0;
    monthly.forEach((month, meters) {
      if (meters > bestKm) {
        bestKm = meters;
        bestMonth = month;
      }
    });

    if (bestMonth == null) return (0, null);
    return (
      bestKm / 1000,
      '${monthNames[bestMonth!.month - 1]} ${bestMonth!.year}',
    );
  }

  static void _updateBestSplit({
    required WorkoutSummary workout,
    required double targetM,
    required Duration? current,
    required void Function(Duration duration) onBetter,
  }) {
    if (workout.distanceMeters < targetM * 0.95) return;
    final split = fastestSplit(
      workout.points,
      targetM,
      workout.duration,
    );
    if (split == null) return;
    if (current == null || split < current) {
      onBetter(split);
    }
  }

  static double _workoutElevation(WorkoutSummary workout) {
    if (workout.elevationGainM > 0) return workout.elevationGainM;
    return WorkoutAnalytics.computeElevationGain(workout.points);
  }

  static double longestMonotonicAscent(List<TrackPoint> points) {
    var best = 0.0;
    var current = 0.0;
    double? prev;

    for (final point in points) {
      final ele = point.elevation;
      if (ele == null) {
        best = math.max(best, current);
        current = 0;
        prev = null;
        continue;
      }
      if (prev != null) {
        if (ele > prev) {
          current += ele - prev;
        } else {
          best = math.max(best, current);
          current = 0;
        }
      }
      prev = ele;
    }
    return math.max(best, current);
  }

  static Duration? fastestSplit(
    List<TrackPoint> points,
    double targetMeters,
    Duration? totalDuration,
  ) {
    if (points.length < 2 || targetMeters <= 0) return null;

    final n = points.length;
    final cumDist = List<double>.filled(n, 0);
    final cumMs = List<int>.filled(n, 0);

    for (var i = 1; i < n; i++) {
      cumDist[i] = cumDist[i - 1] +
          _haversineMeters(
            points[i - 1].latitude,
            points[i - 1].longitude,
            points[i].latitude,
            points[i].longitude,
          );

      final t0 = points[0].time;
      final ti = points[i].time;
      if (t0 != null && ti != null) {
        cumMs[i] = ti.difference(t0).inMilliseconds;
      }
    }

    if (cumDist.last < targetMeters) return null;

    final hasTimestamps = cumMs.last > 0;
    if (!hasTimestamps && totalDuration != null && totalDuration.inSeconds > 0) {
      for (var i = 1; i < n; i++) {
        final fraction = cumDist[i] / cumDist.last;
        cumMs[i] = (totalDuration.inMilliseconds * fraction).round();
      }
    } else if (!hasTimestamps) {
      return null;
    }

    Duration? best;
    for (var start = 0; start < n - 1; start++) {
      for (var end = start + 1; end < n; end++) {
        final segDist = cumDist[end] - cumDist[start];
        if (segDist < targetMeters) continue;

        final segMs = cumMs[end] - cumMs[start];
        final interpolatedMs = segDist <= 0
            ? segMs
            : (segMs * (targetMeters / segDist)).round();
        final duration = Duration(milliseconds: interpolatedMs);

        if (best == null || duration < best) {
          best = duration;
        }
        break;
      }
    }
    return best;
  }

  static List<StatTrendPoint> _allTimeTrend({
    required List<WorkoutSummary> workouts,
    required ProfileStatMetric metric,
  }) {
    final first = workouts.first.startedAt!;
    final last = workouts.last.startedAt!;
    final firstMonth = DateTime(first.year, first.month, 1);
    final lastMonth = DateTime(last.year, last.month, 1);
    final spanMonths =
        (lastMonth.year - firstMonth.year) * 12 +
        lastMonth.month -
        firstMonth.month +
        1;

    if (spanMonths <= 14) {
      const monthNames = [
        'Янв',
        'Фев',
        'Мар',
        'Апр',
        'Май',
        'Июн',
        'Июл',
        'Авг',
        'Сен',
        'Окт',
        'Ноя',
        'Дек',
      ];
      final points = <StatTrendPoint>[];
      var cursor = firstMonth;
      while (!cursor.isAfter(lastMonth)) {
        final monthEnd = _subtractMonths(cursor, -1);
        final monthWorkouts = workouts.where((w) {
          final d = w.startedAt!;
          return !d.isBefore(cursor) && d.isBefore(monthEnd);
        }).toList();
        points.add(
          StatTrendPoint(
            label: monthNames[cursor.month - 1],
            value: _metricValue(monthWorkouts, metric),
            date: cursor,
          ),
        );
        cursor = monthEnd;
      }
      return points;
    }

    final points = <StatTrendPoint>[];
    for (var year = first.year; year <= last.year; year++) {
      final yearWorkouts =
          workouts.where((w) => w.startedAt!.year == year).toList();
      points.add(
        StatTrendPoint(
          label: year.toString(),
          value: _metricValue(yearWorkouts, metric),
          date: DateTime(year),
        ),
      );
    }
    return points;
  }

  static double _metricValue(
    List<WorkoutSummary> workouts,
    ProfileStatMetric metric,
  ) {
    switch (metric) {
      case ProfileStatMetric.workouts:
        return workouts.length.toDouble();
      case ProfileStatMetric.distance:
        return workouts.fold(0.0, (s, w) => s + w.distanceMeters) / 1000;
      case ProfileStatMetric.duration:
        final seconds = workouts.fold<int>(
          0,
          (s, w) => s + (w.duration?.inSeconds ?? 0),
        );
        return seconds / 3600;
      case ProfileStatMetric.elevation:
        return workouts.fold(0.0, (s, w) => s + _workoutElevation(w));
      case ProfileStatMetric.calories:
        return workouts.fold<int>(0, (s, w) => s + (w.calories ?? 0)).toDouble();
    }
  }

  static String formatTotalValue(ProfileStatMetric metric, ProfileTotals totals) {
    switch (metric) {
      case ProfileStatMetric.workouts:
        return '${totals.workoutCount}';
      case ProfileStatMetric.distance:
        return '${(totals.totalDistanceM / 1000).toStringAsFixed(1)} км';
      case ProfileStatMetric.duration:
        return formatDurationLong(totals.totalDuration);
      case ProfileStatMetric.elevation:
        return '${totals.totalElevationM.round()} м';
      case ProfileStatMetric.calories:
        return '${totals.totalCalories}';
    }
  }

  static String formatTrendValue(ProfileStatMetric metric, double value) {
    switch (metric) {
      case ProfileStatMetric.workouts:
        return value.round().toString();
      case ProfileStatMetric.distance:
        return '${value.toStringAsFixed(1)} км';
      case ProfileStatMetric.duration:
        final totalMinutes = (value * 60).round();
        final h = totalMinutes ~/ 60;
        final m = totalMinutes % 60;
        if (h > 0) return '$h ч $m м';
        return '$m м';
      case ProfileStatMetric.elevation:
        return '${value.round()} м';
      case ProfileStatMetric.calories:
        return '${value.round()} ккал';
    }
  }

  static String formatDurationLong(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '$hours ч $minutes м';
    if (duration.inMinutes > 0) return '${duration.inMinutes} м';
    return '${duration.inSeconds} с';
  }

  static String formatSplitDuration(Duration? duration) {
    if (duration == null) return '—';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return "$minutes'${seconds.toString().padLeft(2, '0')}''";
  }

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * math.pi / 180.0;

  static DateTime _subtractMonths(DateTime date, int months) {
    var month = date.month - months;
    var year = date.year;
    while (month <= 0) {
      month += 12;
      year--;
    }
    while (month > 12) {
      month -= 12;
      year++;
    }
    return DateTime(year, month, 1);
  }
}
