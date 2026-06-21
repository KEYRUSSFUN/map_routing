import 'dart:async';

import 'package:flutter/material.dart';
import 'package:map_routing/core/navigation/app_route_observer.dart';
import 'package:map_routing/data/models/achievement.dart';
import 'package:map_routing/data/models/moment.dart';
import 'package:map_routing/data/models/story.dart';
import 'package:map_routing/data/models/workout_summary.dart';
import 'package:map_routing/data/services/achievement_service.dart';
import 'package:map_routing/data/services/gpx_workout_service.dart';
import 'package:map_routing/data/services/moment_service.dart';
import 'package:map_routing/data/services/statistics_service.dart';
import 'package:map_routing/data/services/story_service.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/features/moments/presentation/moment_comments_sheet.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';
import 'package:map_routing/features/profile/widgets/achievement_details_sheet.dart';
import 'package:map_routing/features/profile/presentation/widgets/profile_statistics_tab.dart';
import 'package:map_routing/features/profile/presentation/workout_detail_page.dart';
import 'package:map_routing/features/stories/presentation/story_viewer_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => UserProfilePageState();
}

class UserProfilePageState extends State<UserProfilePage> with RouteAware {
  String name = '';
  String country = '';
  String userAvatarUrl = '';
  String userCoverUrl = '';
  String? userCoverPreset;

  double? distance;
  int? steps;
  double? calories;
  String? _weekChangeLabel;
  List<double>? _weeklyActivityData;
  bool _weeklyStatsLoading = false;

  bool isLoading = true;
  ProfileTab _selectedTab = ProfileTab.events;

  List<AchievementStatus> _achievements = [];
  bool _achievementsLoading = false;
  bool _achievementsLoaded = false;
  final _allAchievementsKey = GlobalKey();

  List<StoryItem> _userStories = [];
  bool _storiesLoading = false;
  bool _storiesLoaded = false;

  List<MomentItem> _userMoments = [];
  bool _momentsLoading = false;
  bool _momentsLoaded = false;

  List<WorkoutSummary> _userWorkouts = [];
  bool _workoutsLoading = false;
  bool _workoutsLoaded = false;

  StoryService? _storyService;
  MomentService? _momentService;
  final _gpxWorkoutService = GpxWorkoutService();

  final userService = UserService();
  final statisticsService = StatisticsService();
  final _achievementService = AchievementService();

  int get _targetUserId => int.tryParse(widget.userId) ?? 0;

  Future<void> _initializeServices() async {
    if (_storyService != null && _momentService != null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _storyService = StoryService(token: token);
      _momentService = MomentService(token: token);
    });
  }

  Future<void> fetchUserInfo() async {
    final data = await userService.fetchOtherUserInfo(userId: widget.userId);

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
      userAvatarUrl = data['avatar_url']?.toString() ?? '';
      userCoverUrl = data['cover_url']?.toString() ?? '';
      userCoverPreset = data['cover_preset']?.toString();
      isLoading = false;
    });
  }

  Future<void> fetchStatistics() async {
    if (_weeklyActivityData == null && mounted) {
      setState(() => _weeklyStatsLoading = true);
    }

    try {
      final snapshot = await statisticsService.fetchProfileSnapshot(
        userId: widget.userId,
      );

      if (!mounted) return;

      setState(() {
        distance = snapshot.totals.distanceKm;
        steps = snapshot.totals.steps;
        calories = snapshot.totals.calories;
        _weekChangeLabel = StatisticsService.formatWeekChangeLabel(
          snapshot.weekOverWeekChangePercent,
        );
        _weeklyActivityData = snapshot.dailyDistanceMeters;
        _weeklyStatsLoading = false;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        distance = 0;
        steps = 0;
        calories = 0;
        _weekChangeLabel = 'Нет данных';
        _weeklyActivityData = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        _weeklyStatsLoading = false;
        isLoading = false;
      });
    }
  }

  Future<void> _loadStories({bool force = false}) async {
    if (_storiesLoading) return;
    if (_targetUserId <= 0) return;
    if (!force && _storiesLoaded) return;
    await _initializeServices();
    if (_storyService == null) return;

    setState(() => _storiesLoading = true);
    try {
      final bundle = await _storyService!.fetchUserStories(_targetUserId);
      if (!mounted) return;
      setState(() {
        _userStories = bundle.stories;
        _storiesLoading = false;
        _storiesLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _storiesLoading = false;
        _storiesLoaded = true;
      });
    }
  }

  Future<void> _loadMoments({bool force = false}) async {
    if (_momentsLoading) return;
    if (_targetUserId <= 0) return;
    if (!force && _momentsLoaded) return;
    await _initializeServices();
    if (_momentService == null) return;

    setState(() => _momentsLoading = true);
    try {
      final moments = await _momentService!.fetchUserMoments(_targetUserId);
      if (!mounted) return;
      setState(() {
        _userMoments = moments;
        _momentsLoading = false;
        _momentsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _momentsLoading = false;
        _momentsLoaded = true;
      });
    }
  }

  Future<void> _loadWorkouts({bool force = false}) async {
    if (_workoutsLoading) return;
    if (!force && _workoutsLoaded) return;

    setState(() => _workoutsLoading = true);
    try {
      final workouts =
          await _gpxWorkoutService.loadRemoteUserWorkouts(widget.userId);
      if (!mounted) return;
      setState(() {
        _userWorkouts = workouts;
        _workoutsLoading = false;
        _workoutsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _workoutsLoading = false;
        _workoutsLoaded = true;
      });
    }
  }

  Future<void> _loadAchievements({bool force = false}) async {
    if (_achievementsLoading) return;
    if (!force && _achievementsLoaded) return;

    setState(() => _achievementsLoading = true);

    try {
      final achievements =
          await _achievementService.fetchForUser(userId: widget.userId);
      if (!mounted) return;
      setState(() {
        _achievements = achievements;
        _achievementsLoading = false;
        _achievementsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _achievementsLoading = false;
        _achievementsLoaded = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    await fetchUserInfo();
    if (!mounted) return;
    unawaited(fetchStatistics());
    unawaited(_initializeServices());
    unawaited(_loadStories());
    unawaited(_loadMoments());
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
    unawaited(_loadData());
  }

  List<ProfileStatPillData> get _statPills => [
        ProfileStatPillData(
          icon: Icons.straighten_rounded,
          label: distance != null && distance! > 0
              ? '${distance!.toStringAsFixed(1)} км'
              : '-- км',
        ),
        ProfileStatPillData(
          icon: Icons.directions_walk_rounded,
          label: steps != null && steps! > 0 ? '$steps шагов' : '-- шагов',
        ),
        ProfileStatPillData(
          icon: Icons.local_fire_department_outlined,
          label: calories != null && calories! > 0
              ? '${calories!.toStringAsFixed(0)} ккал'
              : '-- ккал',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    if (isLoading && name.isEmpty) {
      return const Scaffold(
        backgroundColor: ProfileColors.scaffoldBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: ProfileColors.scaffoldBg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileHeader(
              name: name,
              location: country.isNotEmpty ? country : 'Страна не указана',
              subtitle: 'Спортсмен',
              avatarUrl: userAvatarUrl.isNotEmpty ? userAvatarUrl : null,
              coverUrl: userCoverUrl.isNotEmpty ? userCoverUrl : null,
              coverPresetId: userCoverPreset,
              statPills: _statPills,
              onBack: () => Navigator.pop(context),
            ),
            ProfileTabBar(
              selected: _selectedTab,
              onChanged: (tab) {
                setState(() => _selectedTab = tab);
                if (tab == ProfileTab.achievements && !_achievementsLoaded) {
                  unawaited(_loadAchievements());
                } else if (tab == ProfileTab.history && !_workoutsLoaded) {
                  unawaited(_loadWorkouts());
                } else if (tab == ProfileTab.statistics && !_workoutsLoaded) {
                  unawaited(_loadWorkouts());
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
      case ProfileTab.events:
        return _buildEventsTab();
      case ProfileTab.statistics:
        return _buildStatisticsTab();
      case ProfileTab.achievements:
        return _buildAchievementsTab();
      case ProfileTab.history:
        return _buildHistoryTab();
    }
  }

  Widget _buildEventsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileStoriesSection(
          stories: _userStories,
          isLoading: _storiesLoading,
          readOnly: true,
          sectionTitle: 'Истории',
          onStoryTap: _openUserStory,
        ),
        const SizedBox(height: 8),
        ProfileMomentsSection(
          moments: _userMoments,
          isLoading: _momentsLoading,
          readOnly: true,
          emptyMessage: 'У пользователя пока нет моментов.',
          onLikeTap: _toggleMomentLike,
          onCommentTap: _openMomentComments,
        ),
      ],
    );
  }

  Widget _buildStatisticsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeeklyActivityBarChart(
          weeklyData: _weeklyActivityData,
          isLoading: _weeklyStatsLoading,
          totalLabel: distance != null && distance! > 0
              ? 'Всего: ${distance!.toStringAsFixed(1)} км'
              : 'Всего: -- км',
          changeLabel: _weekChangeLabel ?? 'Нет данных',
        ),
        const SizedBox(height: 20),
        ProfileStatisticsTab(
          workouts: _userWorkouts,
          isLoading: _workoutsLoading,
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_workoutsLoading && !_workoutsLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_userWorkouts.isEmpty) {
      return _buildEmptyTab('У пользователя пока нет доступных тренировок.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionHeader(title: 'Тренировки'),
        const SizedBox(height: 12),
        for (final workout in _userWorkouts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildWorkoutActivityCard(workout),
          ),
      ],
    );
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
    } else if (workout.description != null && workout.description!.isNotEmpty) {
      detailLine = workout.description;
    } else if (workout.effortLevel != null) {
      detailLine = 'Нагрузка: ${workout.effortLevel} из 5';
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
      stats: [
        ActivityStat(
          value: WorkoutFormatters.formatDistanceKm(workout.distanceMeters),
          label: 'Дистанция',
        ),
        ActivityStat(
          value: WorkoutFormatters.formatPace(
            workout.duration,
            workout.distanceMeters,
          ),
          label: 'Средний темп',
        ),
        ActivityStat(
          value: WorkoutFormatters.formatDurationLong(workout.duration),
          label: 'Время',
        ),
      ],
    );
  }

  Future<void> _openUserStory(StoryItem story) async {
    if (_storyService == null || _userStories.isEmpty) return;

    final initialIndex = _userStories.indexWhere((item) => item.id == story.id);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StoryViewerPage(
          storyService: _storyService!,
          userName: name.isNotEmpty ? name : 'Пользователь',
          avatarUrl: userAvatarUrl.isNotEmpty ? userAvatarUrl : null,
          userId: _targetUserId,
          stories: _userStories,
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
          canDelete: false,
        ),
      ),
    );
  }

  Future<void> _toggleMomentLike(int index) async {
    if (_momentService == null) return;
    final moment = _userMoments[index];
    try {
      final result = await _momentService!.toggleLike(moment.id);
      if (!mounted) return;
      setState(() {
        _userMoments[index] = moment.copyWith(
          likedByMe: result.liked,
          likesCount: result.likesCount,
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось поставить лайк')),
      );
    }
  }

  Future<void> _openMomentComments(int index) async {
    if (_momentService == null) return;
    final moment = _userMoments[index];
    final newCount = await showMomentCommentsSheet(
      context,
      momentService: _momentService!,
      moment: moment,
    );
    if (!mounted || newCount == null) return;
    setState(() {
      _userMoments[index] = moment.copyWith(commentsCount: newCount);
    });
  }

  Widget _buildAchievementsTab() {
    if (_achievementsLoading && !_achievementsLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final recent = _achievementService.recentUnlocked(_achievements);
    final unlockedCount =
        _achievements.where((achievement) => achievement.unlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionHeader(
          title: 'Недавние достижения',
          trailing: _achievements.length > 4 ? 'Смотреть все' : null,
          onTrailingTap: () {
            final target = _allAchievementsKey.currentContext;
            if (target != null) {
              Scrollable.ensureVisible(
                target,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
        ),
        const SizedBox(height: 16),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'У пользователя пока нет достижений.',
              textAlign: TextAlign.center,
              style: profileSubtitleStyle(),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            children: recent
                .map((status) => _buildAchievementBadge(status))
                .toList(),
          ),
        const SizedBox(height: 24),
        ProfileSectionHeader(
          key: _allAchievementsKey,
          title: 'Все достижения',
          trailing: '$unlockedCount/${_achievements.length}',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 16,
          alignment: WrapAlignment.spaceAround,
          children: _achievements
              .map((status) => _buildAchievementBadge(status))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildAchievementBadge(AchievementStatus status) {
    return GestureDetector(
      onTap: () => AchievementDetailsSheet.show(context, status: status),
      child: AchievementBadge(
        icon: status.definition.icon,
        label: status.definition.title,
        locked: !status.unlocked,
      ),
    );
  }

  Widget _buildEmptyTab(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: profileSubtitleStyle(),
      ),
    );
  }
}
