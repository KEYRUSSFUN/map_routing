import 'package:flutter/material.dart';
import 'package:map_routing/data/services/friend_service.dart';
import 'package:map_routing/data/services/statistics_service.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/core/widgets/app_bottom_nav_bar.dart';
import 'package:map_routing/data/models/workout_summary.dart';
import 'package:map_routing/data/services/gpx_workout_service.dart';
import 'package:map_routing/features/profile/presentation/edit_profile.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';
import 'package:map_routing/features/profile/presentation/settings_page.dart';
import 'package:map_routing/features/profile/presentation/workout_detail_page.dart';
import 'package:map_routing/core/navigation/app_route_observer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> with RouteAware {
  late Future<List<double>> weeklyActivityDataFuture;
  late Future<List<Map<String, dynamic>>> friendRequestsFuture;

  String name = '';
  String country = '';
  String userAvatarUrl = '';

  double? distance;
  int? steps;
  double? calories;
  String? _weekChangeLabel;

  bool isLoading = true;
  ProfileTab _selectedTab = ProfileTab.statistics;

  List<WorkoutSummary> _workouts = [];
  bool _workoutsLoading = false;
  bool _workoutsLoaded = false;

  final userService = UserService();
  final statisticsService = StatisticsService();
  final _gpxWorkoutService = GpxWorkoutService();
  FriendService? friendService;

  void refreshData() {
    fetchUserInfo();
    fetchStatistics();
    fetchFriendRequests();
    _loadWorkouts(force: true);
  }

  Future<void> _loadWorkouts({bool force = false}) async {
    if (_workoutsLoading) return;
    if (_workoutsLoaded && !force) return;

    setState(() => _workoutsLoading = true);

    double? weightKg;
    final userData = await userService.fetchUserInfo();
    if (userData != null && userData['weight'] != null) {
      weightKg = double.tryParse(userData['weight'].toString());
    }

    final workouts =
        await _gpxWorkoutService.loadWorkouts(userWeightKg: weightKg);

    if (!mounted) return;
    setState(() {
      _workouts = workouts;
      _workoutsLoading = false;
      _workoutsLoaded = true;
    });
  }

  void fetchStatistics() async {
    final summary = await statisticsService.fetchAllWeeklyStats();
    final rawData = await statisticsService.fetchWeeklyStats();
    final weekChange =
        await statisticsService.fetchWeekOverWeekChangePercent();

    final List<double> distancePerDay =
        rawData.map((day) => (day['distance'] as double?) ?? 0.0).toList();

    if (!mounted) return;

    setState(() {
      distance = summary.distanceKm;
      steps = summary.steps;
      calories = summary.calories;
      _weekChangeLabel =
          StatisticsService.formatWeekChangeLabel(weekChange);
      weeklyActivityDataFuture = Future.value(distancePerDay);
    });
  }

  void fetchUserInfo() async {
    final data = await userService.fetchUserInfo();

    if (!mounted) return;

    if (data == null) {
      setState(() {
        name = 'Ошибка загрузки';
        country = '';
        isLoading = false;
      });
      return;
    }

    setState(() {
      name = data['name'] ?? 'Без имени';
      country = data['country'] ?? '';
      isLoading = false;
    });
  }

  void fetchFriendRequests() async {
    if (friendService == null) return;
    try {
      final requests = await friendService!.fetchFriendRequests();
      setState(() {
        friendRequestsFuture = Future.value(requests);
      });
    } catch (e) {
      setState(() {
        friendRequestsFuture = Future.value([]);
      });
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    if (friendService == null) return;
    try {
      await friendService!.acceptFriendRequest(requestId);
      fetchFriendRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запрос принят')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> rejectFriendRequest(String requestId) async {
    if (friendService == null) return;
    try {
      await friendService!.rejectFriendRequest(requestId);
      fetchFriendRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запрос отклонён')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    weeklyActivityDataFuture = Future.value([]);
    friendRequestsFuture = Future.value([]);
    _initializeFriendService().then((_) {
      fetchUserInfo();
      fetchStatistics();
      fetchFriendRequests();
      _loadWorkouts();
    });
  }

  Future<void> _initializeFriendService() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return;
    setState(() {
      friendService = FriendService(token: token);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    fetchStatistics();
    fetchUserInfo();
    fetchFriendRequests();
    _loadWorkouts(force: true);
  }

  List<ProfileStatPillData> get _statPills => [
        ProfileStatPillData(
          icon: Icons.directions_run,
          label:
              distance != null ? '${distance!.toStringAsFixed(1)} км' : '-- км',
        ),
        ProfileStatPillData(
          icon: Icons.terrain,
          label: steps != null ? '$steps шагов' : '-- шагов',
        ),
        ProfileStatPillData(
          icon: Icons.emoji_events_outlined,
          label: calories != null
              ? '${calories!.toStringAsFixed(0)} ккал'
              : '-- ккал',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: ProfileColors.scaffoldBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: ProfileColors.scaffoldBg,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: AppBottomNavBar.scrollEndPadding(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileHeader(
              name: name,
              location: country,
              subtitle: 'Спортсмен',
              avatarUrl: userAvatarUrl.isNotEmpty ? userAvatarUrl : null,
              statPills: _statPills,
              onAvatarTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (context) => const EditProfilePage(),
                  ),
                );
              },
              onSettings: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  ),
                );
              },
            ),
            ProfileTabBar(
              selected: _selectedTab,
              onChanged: (tab) {
                setState(() => _selectedTab = tab);
                if (tab == ProfileTab.history || tab == ProfileTab.statistics) {
                  _loadWorkouts();
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _buildTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case ProfileTab.statistics:
        return _buildStatisticsTab();
      case ProfileTab.achievements:
        return _buildAchievementsTab();
      case ProfileTab.history:
        return _buildHistoryTab();
    }
  }

  Widget _buildStatisticsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeeklyActivityBarChart(
          weeklyDataFuture: weeklyActivityDataFuture,
          totalLabel: distance != null
              ? 'Всего: ${distance!.toStringAsFixed(1)} км'
              : 'Всего: -- км',
          changeLabel: _weekChangeLabel,
        ),
        const SizedBox(height: 20),
        const ProfileSectionHeader(title: 'Личные рекорды'),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(
              child: PersonalRecordCard(
                title: 'Самые быстрые 5 км',
                value: '18:42',
                badge: 'НОВЫЙ РЕКОРД',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: PersonalRecordCard(
                title: 'Самый длинный забег',
                value: '42.2 км',
                subtitle: 'Марафон',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const ProfileSectionHeader(title: 'Недавняя активность'),
        const SizedBox(height: 12),
        ..._buildRecentWorkoutCards(limit: 2),
      ],
    );
  }

  List<Widget> _buildRecentWorkoutCards({required int limit}) {
    if (_workoutsLoading && _workouts.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_workouts.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Завершите тренировку на карте — она появится здесь.',
            style: profileSubtitleStyle(),
          ),
        ),
      ];
    }

    return _workouts
        .take(limit)
        .map(
          (workout) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildWorkoutActivityCard(workout),
          ),
        )
        .toList();
  }

  Widget _buildWorkoutActivityCard(WorkoutSummary workout) {
    final activity = workout.activityType;
    final subtitleParts = <String>[
      WorkoutFormatters.formatDateTime(workout.startedAt),
      if (activity != null) activity.labelRu,
    ];

    String? detailLine;
    if (workout.tags.isNotEmpty) {
      detailLine = workout.tags.map((t) => '#$t').join(' ');
    } else if (workout.description != null &&
        workout.description!.isNotEmpty) {
      detailLine = workout.description;
    } else if (workout.effortLevel != null) {
      detailLine = 'Нагрузка: ${workout.effortLevel} из 5';
    }

    final extraStats = <ActivityStat>[
      ActivityStat(
        value: WorkoutFormatters.formatDistanceKm(workout.distanceMeters),
        label: 'Дистанция',
      ),
      ActivityStat(
        value: WorkoutFormatters.formatDurationLong(workout.duration),
        label: 'Время',
      ),
      ActivityStat(
        value: WorkoutFormatters.formatPace(
          workout.duration,
          workout.distanceMeters,
        ),
        label: 'Средний темп',
      ),
    ];

    if (workout.calories != null) {
      extraStats.add(
        ActivityStat(
          value: '${workout.calories}',
          label: 'Ккал',
        ),
      );
    }

    return ActivityCard(
      title: workout.title,
      subtitle: subtitleParts.join(' · '),
      detailLine: detailLine,
      icon: activity?.icon ?? Icons.directions_run,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutDetailPage(workout: workout),
          ),
        );
      },
      stats: extraStats.length > 3 ? extraStats.sublist(0, 3) : extraStats,
    );
  }

  Widget _buildAchievementsTab() {
    const recent = [
      (Icons.landscape, 'Пиковая форма', false),
      (Icons.speed, 'Демон скорости', true),
      (Icons.local_fire_department, '7 дней подряд', false),
      (Icons.lock_outline, 'Путешественник', true),
    ];

    const all = [
      (Icons.landscape, 'Пиковая форма', false, false),
      (Icons.speed, 'Демон скорости', false, true),
      (Icons.local_fire_department, '7 дней подряд', false, false),
      (Icons.emoji_events_outlined, 'Ранняя пташка', false, false),
      (Icons.directions_run, 'Ниндзя', false, false),
      (Icons.directions_bike, 'Сотня', false, false),
      (Icons.lock_outline, 'Путешественник', true, false),
      (Icons.lock_outline, 'Исследователь', true, false),
      (Icons.lock_outline, 'Мировой путешественник', true, false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionHeader(
          title: 'Недавние достижения',
          trailing: 'Смотреть все',
          onTrailingTap: () {},
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: recent
              .map(
                (item) => AchievementBadge(
                  icon: item.$1,
                  label: item.$2,
                  locked: item.$3,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        const ProfileSectionHeader(title: 'Все достижения'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 16,
          alignment: WrapAlignment.spaceAround,
          children: all
              .map(
                (item) => AchievementBadge(
                  icon: item.$1,
                  label: item.$2,
                  locked: item.$3,
                  highlighted: item.$4,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (!_workoutsLoaded && !_workoutsLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadWorkouts());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionHeader(title: 'История активности'),
        const SizedBox(height: 12),
        if (_workoutsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_workouts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Пока нет сохранённых маршрутов.\nЗапишите тренировку на карте.',
              textAlign: TextAlign.center,
              style: profileSubtitleStyle(),
            ),
          )
        else
          ..._workouts.map(
            (workout) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildWorkoutActivityCard(workout),
            ),
          ),
      ],
    );
  }
}
