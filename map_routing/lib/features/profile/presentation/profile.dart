import 'dart:async';

import 'package:flutter/material.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/models/achievement.dart';
import 'package:map_routing/data/models/challenge.dart';
import 'package:map_routing/data/models/moment.dart';
import 'package:map_routing/data/models/story.dart';
import 'package:map_routing/data/services/achievement_service.dart';
import 'package:map_routing/data/services/challenge_service.dart';
import 'package:map_routing/data/services/friend_service.dart';
import 'package:map_routing/data/services/moment_service.dart';
import 'package:map_routing/data/services/story_service.dart';
import 'package:map_routing/features/challenges/presentation/challenge_detail_page.dart';
import 'package:map_routing/features/home/home_page_controller.dart';
import 'package:map_routing/features/moments/presentation/moment_comments_sheet.dart';
import 'package:map_routing/features/moments/presentation/publish_moment_sheet.dart';
import 'package:map_routing/features/stories/presentation/publish_story_dialog.dart';
import 'package:map_routing/features/stories/presentation/story_viewer_page.dart';
import 'package:map_routing/data/services/profile_cache.dart';
import 'package:map_routing/data/services/statistics_service.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/core/widgets/app_bottom_nav_bar.dart';
import 'package:map_routing/data/models/planned_workout.dart';
import 'package:map_routing/data/models/workout_summary.dart';
import 'package:map_routing/data/services/gpx_workout_service.dart';
import 'package:map_routing/features/profile/presentation/edit_profile.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';
import 'package:map_routing/features/profile/presentation/settings_page.dart';
import 'package:map_routing/features/profile/widgets/achievement_details_sheet.dart';
import 'package:map_routing/features/profile/widgets/planned_workouts_section.dart';
import 'package:map_routing/features/profile/presentation/workout_detail_page.dart';
import 'package:map_routing/core/navigation/app_route_observer.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.onShowRouteOnMap,
    this.onOpenPlannedWorkout,
  });

  final ValueChanged<WorkoutSummary>? onShowRouteOnMap;
  final ValueChanged<PlannedWorkout>? onOpenPlannedWorkout;

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> with RouteAware {
  late Future<List<Map<String, dynamic>>> friendRequestsFuture;

  String name = '';
  String country = '';
  String userAvatarUrl = '';

  double? distance;
  int? steps;
  double? calories;
  double? _weeklyDistanceKm;
  String? _weekChangeLabel;
  List<double>? _weeklyActivityData;
  bool _weeklyStatsLoading = false;

  bool isLoading = true;
  ProfileTab _selectedTab = ProfileTab.statistics;

  List<WorkoutSummary> _workouts = [];
  bool _workoutsLoading = false;
  bool _workoutsLoaded = false;
  bool _historySelectionMode = false;
  final Set<String> _selectedWorkoutIds = {};
  bool _workoutsDeleting = false;

  List<AchievementStatus> _achievements = [];
  bool _achievementsLoading = false;
  final _allAchievementsKey = GlobalKey();

  List<ChallengeSummary> _joinedChallenges = [];
  bool _challengesLoading = false;
  ChallengeService? _challengeService;
  final GlobalKey _challengesSectionKey = GlobalKey();
  final GlobalKey<PlannedWorkoutsSectionState> _plannedWorkoutsKey =
      GlobalKey<PlannedWorkoutsSectionState>();

  List<StoryItem> _myStories = [];
  bool _storiesLoading = false;
  StoryService? _storyService;

  List<MomentItem> _myMoments = [];
  bool _momentsLoading = false;
  MomentService? _momentService;

  static const _refreshCooldown = Duration(seconds: 20);
  DateTime? _lastRefreshAt;

  final userService = UserService();
  final statisticsService = StatisticsService();
  final _gpxWorkoutService = GpxWorkoutService();
  final _achievementService = AchievementService();
  FriendService? friendService;

  void refreshData({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) < _refreshCooldown) {
      return;
    }
    _lastRefreshAt = now;

    if (force) {
      GpxWorkoutService.invalidateMemoryCache(notify: false);
    }

    fetchUserInfo(force: force);
    fetchStatistics(force: force);
    fetchFriendRequests();
    _loadWorkouts(force: force);
    _loadAchievements(force: force);
    _loadChallenges(force: force);
    _loadStories(force: force);
    _loadMoments(force: force);
    _plannedWorkoutsKey.currentState?.reload(force: force);
  }

  Future<void> _persistProfileCache() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await UserWorkoutStorage.instance.syncUserIdFromToken(
      prefs.getString('jwt_token'),
    );
    if (userId == null) return;

    await ProfileCache.instance.save(
      userId: userId,
      snapshot: ProfileCacheSnapshot(
        name: name,
        country: country,
        avatarUrl: userAvatarUrl,
        distanceKm: distance ?? 0,
        steps: steps ?? 0,
        calories: calories ?? 0,
        weeklyDistanceKm: _weeklyDistanceKm ?? 0,
        weekChangeLabel: _weekChangeLabel ?? '',
        weeklyActivity: _weeklyActivityData ??
            const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      ),
    );
  }

  Future<void> _hydrateFromProfileCache() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await UserWorkoutStorage.instance.syncUserIdFromToken(
      prefs.getString('jwt_token'),
    );
    if (userId == null || !mounted) return;

    final snapshot = await ProfileCache.instance.load(userId: userId);
    if (snapshot == null || !mounted) return;

    setState(() {
      name = snapshot.name;
      country = snapshot.country;
      userAvatarUrl = snapshot.avatarUrl;
      distance = snapshot.distanceKm;
      steps = snapshot.steps;
      calories = snapshot.calories;
      _weeklyDistanceKm = snapshot.weeklyDistanceKm;
      _weekChangeLabel = snapshot.weekChangeLabel;
      _weeklyActivityData = snapshot.weeklyActivity;
      isLoading = false;
    });
  }

  Future<void> _bootstrapProfile() async {
    await _hydrateFromProfileCache();
    unawaited(_initializeFriendService().then((_) {
      fetchFriendRequests();
      _loadChallenges();
      _loadStories();
    }));
    fetchUserInfo();
    fetchStatistics();
    unawaited(_loadWorkouts());
  }

  Future<void> _loadAchievements({bool force = false}) async {
    if (_achievementsLoading) return;
    if (!force && _achievements.isNotEmpty) return;

    setState(() => _achievementsLoading = true);

    try {
      final result = await _achievementService.sync();

      if (!mounted) return;
      setState(() {
        _achievements = result.all;
        _achievementsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _achievementsLoading = false);
      AppSnackBar.show(context, 'Не удалось загрузить достижения: $e');
    }
  }

  Future<void> _loadWorkouts({bool force = false}) async {
    if (_workoutsLoading) {
      if (!force) return;
    }

    final prefs = await SharedPreferences.getInstance();
    final currentUserId = await UserWorkoutStorage.instance.syncUserIdFromToken(
      prefs.getString('jwt_token'),
    );

    if (!mounted) return;
    setState(() => _workoutsLoading = true);

    try {
      double? weightKg;
      int? userAge;
      final userData = await userService.fetchUserInfo();
      if (userData != null) {
        if (userData['weight'] != null) {
          weightKg = double.tryParse(userData['weight'].toString());
        }
        final ageRaw = userData['age'];
        userAge = ageRaw is int ? ageRaw : int.tryParse(ageRaw?.toString() ?? '');
      }

      final workouts = await _gpxWorkoutService.loadWorkouts(
        userWeightKg: weightKg,
        userAge: userAge,
        force: true,
      );

      if (!mounted) return;
      setState(() {
        _workouts = workouts;
        _workoutsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось обновить историю маршрутов');
    } finally {
      if (mounted) {
        setState(() => _workoutsLoading = false);
      }
    }
  }

  static bool _weeklyDataEqual(List<double>? a, List<double>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> fetchStatistics({bool force = false}) async {
    if (_weeklyActivityData == null && mounted) {
      setState(() => _weeklyStatsLoading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await UserWorkoutStorage.instance.syncUserIdFromToken(
        prefs.getString('jwt_token'),
      );
      if (force) {
        statisticsService.clearCache();
      }

      final snapshot = await statisticsService.fetchProfileSnapshot();

      if (!mounted) return;

      final weekChangeLabel =
          StatisticsService.formatWeekChangeLabel(snapshot.weekOverWeekChangePercent);
      final unchanged = distance == snapshot.totals.distanceKm &&
          steps == snapshot.totals.steps &&
          calories == snapshot.totals.calories &&
          _weeklyDistanceKm == snapshot.week.distanceKm &&
          _weekChangeLabel == weekChangeLabel &&
          _weeklyDataEqual(_weeklyActivityData, snapshot.dailyDistanceMeters);

      if (unchanged) {
        if (_weeklyStatsLoading || isLoading) {
          setState(() {
            _weeklyStatsLoading = false;
            isLoading = false;
          });
        }
        return;
      }

      setState(() {
        distance = snapshot.totals.distanceKm;
        steps = snapshot.totals.steps;
        calories = snapshot.totals.calories;
        _weeklyDistanceKm = snapshot.week.distanceKm;
        _weekChangeLabel = weekChangeLabel;
        _weeklyActivityData = snapshot.dailyDistanceMeters;
        _weeklyStatsLoading = false;
        isLoading = false;
      });
      unawaited(_persistProfileCache());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        distance = 0;
        steps = 0;
        calories = 0;
        _weeklyDistanceKm = 0;
        _weekChangeLabel = 'Не удалось загрузить статистику';
        _weeklyActivityData = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        _weeklyStatsLoading = false;
      });
      AppSnackBar.show(context, 'Не удалось загрузить статистику');
    }
  }

  void fetchUserInfo({bool force = false}) async {
    final data = await userService.fetchUserInfo(force: force);

    if (!mounted) return;

    if (data == null) {
      setState(() {
        if (name.isEmpty) name = 'Ошибка загрузки';
        isLoading = false;
      });
      return;
    }

    setState(() {
      name = data['name'] ?? 'Без имени';
      country = data['country'] ?? '';
      userAvatarUrl = data['avatar_url']?.toString() ?? '';
      isLoading = false;
    });
    unawaited(_persistProfileCache());
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
      AppSnackBar.show(context, 'Запрос принят');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Ошибка: $e');
    }
  }

  Future<void> rejectFriendRequest(String requestId) async {
    if (friendService == null) return;
    try {
      await friendService!.rejectFriendRequest(requestId);
      fetchFriendRequests();
      if (!mounted) return;
      AppSnackBar.show(context, 'Запрос отклонён');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Ошибка: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    friendRequestsFuture = Future.value([]);
    unawaited(_bootstrapProfile());
  }

  Future<void> _initializeFriendService() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return;
    setState(() {
      friendService = FriendService(token: token);
      _challengeService = ChallengeService(token: token);
      _storyService = StoryService(token: token);
      _momentService = MomentService(token: token);
    });
  }

  Future<void> _loadStories({bool force = false}) async {
    if (_storiesLoading) return;
    if (_storyService == null) {
      await _initializeFriendService();
    }
    if (_storyService == null) return;
    if (!force && _myStories.isNotEmpty) return;

    setState(() => _storiesLoading = true);
    try {
      final stories = await _storyService!.fetchMyStories();
      if (!mounted) return;
      setState(() {
        _myStories = stories;
        _storiesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _storiesLoading = false);
    }
  }

  Future<void> _openPublishStoryDialog() async {
    if (_storyService == null) return;
    final published = await showPublishStoryDialog(
      context,
      storyService: _storyService!,
    );
    if (published == true) {
      await _loadStories(force: true);
    }
  }

  Future<void> _openMyStory(StoryItem story) async {
    if (_storyService == null) return;

    final bundle = StoryUserBundle(
      userId: 0,
      name: name.isNotEmpty ? name : 'Вы',
      avatarUrl: userAvatarUrl.isNotEmpty ? userAvatarUrl : null,
      stories: _myStories,
    );

    final initialIndex = _myStories.indexWhere((item) => item.id == story.id);
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StoryViewerPage(
          storyService: _storyService!,
          userName: bundle.name,
          avatarUrl: bundle.avatarUrl,
          userId: bundle.userId,
          stories: bundle.stories,
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
          canDelete: true,
        ),
      ),
    );
    if (changed == true) {
      await _loadStories(force: true);
    }
  }

  Future<void> _loadMoments({bool force = false}) async {
    if (_momentsLoading) return;
    if (_momentService == null) {
      await _initializeFriendService();
    }
    if (_momentService == null) return;
    if (!force && _myMoments.isNotEmpty) return;

    setState(() => _momentsLoading = true);
    try {
      final moments = await _momentService!.fetchMyMoments();
      if (!mounted) return;
      setState(() {
        _myMoments = moments;
        _momentsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _momentsLoading = false);
    }
  }

  Future<void> _openPublishMomentSheet() async {
    if (_momentService == null) return;
    final published = await showPublishMomentSheet(
      context,
      momentService: _momentService!,
    );
    if (published == true) {
      await _loadMoments(force: true);
      await HomePageController.instance.refresh(force: true);
    }
  }

  Future<void> _toggleMomentLike(int index) async {
    if (_momentService == null) return;
    final moment = _myMoments[index];
    try {
      final result = await _momentService!.toggleLike(moment.id);
      if (!mounted) return;
      setState(() {
        _myMoments[index] = moment.copyWith(
          likedByMe: result.liked,
          likesCount: result.likesCount,
        );
      });
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось поставить лайк');
    }
  }

  Future<void> _openMomentComments(int index) async {
    if (_momentService == null) return;
    final moment = _myMoments[index];
    final newCount = await showMomentCommentsSheet(
      context,
      momentService: _momentService!,
      moment: moment,
    );
    if (!mounted || newCount == null) return;
    setState(() {
      _myMoments[index] = moment.copyWith(commentsCount: newCount);
    });
  }

  Future<void> _deleteMoment(int index) async {
    if (_momentService == null) return;
    final moment = _myMoments[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить момент?'),
        content: const Text('Запись будет удалена из профиля и ленты.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _momentService!.deleteMoment(moment.id);
      if (!mounted) return;
      setState(() => _myMoments.removeAt(index));
      await HomePageController.instance.refresh(force: true);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось удалить момент');
    }
  }

  Future<void> _loadChallenges({bool force = false}) async {
    if (_challengesLoading) return;
    if (_challengeService == null) {
      await _initializeFriendService();
    }
    if (_challengeService == null) return;
    if (!force && _joinedChallenges.isNotEmpty) return;

    setState(() => _challengesLoading = true);

    try {
      final all = await _challengeService!.fetchChallenges();
      if (!mounted) return;
      setState(() {
        _joinedChallenges = all.where((c) => c.isJoined).toList();
        _challengesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _challengesLoading = false);
    }
  }

  Future<void> _openChallenge(ChallengeSummary challenge) async {
    if (_challengeService == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChallengeDetailPage(
          challengeId: challenge.id,
          challengeService: _challengeService!,
        ),
      ),
    );
    _loadChallenges(force: true);
  }

  Future<void> scrollToChallenges() async {
    if (_selectedTab != ProfileTab.statistics) {
      setState(() => _selectedTab = ProfileTab.statistics);
    }

    await _loadChallenges(force: true);
    if (!mounted) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final sectionContext = _challengesSectionKey.currentContext;
    if (sectionContext == null) return;

    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
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
    refreshData(force: false);
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
    if (isLoading && name.isEmpty) {
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
                if (tab == ProfileTab.history && !_workoutsLoaded) {
                  _loadWorkouts();
                }
                if (tab == ProfileTab.achievements && _achievements.isEmpty) {
                  _loadAchievements();
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
          weeklyData: _weeklyActivityData,
          isLoading: _weeklyStatsLoading,
          totalLabel: _weeklyDistanceKm != null
              ? 'За неделю: ${_weeklyDistanceKm!.toStringAsFixed(1)} км'
              : 'За неделю: -- км',
          changeLabel: _weekChangeLabel,
        ),
        const SizedBox(height: 20),
        PlannedWorkoutsSection(
          key: _plannedWorkoutsKey,
          onOpenOnMap: (workout) => widget.onOpenPlannedWorkout?.call(workout),
        ),
        const SizedBox(height: 20),
        const ProfileSectionHeader(title: 'Личные рекорды'),
        const SizedBox(height: 12),
        const Row(
          children: [
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
        ProfileStoriesSection(
          stories: _myStories,
          isLoading: _storiesLoading,
          onAddTap: _openPublishStoryDialog,
          onStoryTap: _openMyStory,
        ),
        const SizedBox(height: 8),
        ProfileMomentsSection(
          moments: _myMoments,
          isLoading: _momentsLoading,
          onAddTap: _openPublishMomentSheet,
          onLikeTap: _toggleMomentLike,
          onCommentTap: _openMomentComments,
          onDeleteTap: _deleteMoment,
        ),
        const SizedBox(height: 8),
        ..._buildChallengesSection(),
      ],
    );
  }

  List<Widget> _buildChallengesSection() {
    if (_challengesLoading && _joinedChallenges.isEmpty) {
      return [
        KeyedSubtree(
          key: _challengesSectionKey,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileSectionHeader(title: 'Челленджи'),
              SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ];
    }

    if (_joinedChallenges.isEmpty) {
      return [
        KeyedSubtree(
          key: _challengesSectionKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ProfileSectionHeader(title: 'Челленджи'),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Присоединяйтесь к челленджам во вкладке «Сообщество».',
                  style: profileSubtitleStyle(),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      KeyedSubtree(
        key: _challengesSectionKey,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileSectionHeader(title: 'Челленджи'),
            SizedBox(height: 12),
          ],
        ),
      ),
      ..._joinedChallenges.map(
        (challenge) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ProfileChallengeProgressCard(
            challenge: challenge,
            onTap: () => _openChallenge(challenge),
          ),
        ),
      ),
    ];
  }

  List<WorkoutSummary> get _myWorkouts => _workouts
      .where((workout) => !workout.isImported)
      .toList(growable: false);

  List<WorkoutSummary> get _importedWorkouts => _workouts
      .where((workout) => workout.isImported)
      .toList(growable: false);

  Widget _buildWorkoutActivityCard(
    WorkoutSummary workout, {
    bool forHistory = false,
  }) {
    final activity = workout.activityType;
    final subtitleParts = <String>[
      WorkoutFormatters.formatDateTime(workout.startedAt),
      if (forHistory && workout.isImported) workout.source.labelRu,
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
      icon: forHistory && workout.isImported
          ? Icons.download_rounded
          : activity?.icon ?? Icons.directions_run,
      selectionMode: forHistory && _historySelectionMode,
      selected: _selectedWorkoutIds.contains(workout.id),
      onSelectedChanged: forHistory && _historySelectionMode
          ? (selected) => _toggleWorkoutSelection(workout.id, selected)
          : null,
      onTap: forHistory && _historySelectionMode
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkoutDetailPage(
                    workout: workout,
                    onShowOnMap: widget.onShowRouteOnMap,
                    onWorkoutUpdated: () => _loadWorkouts(force: true),
                  ),
                ),
              );
            },
      onLongPress: forHistory && !_historySelectionMode
          ? () => _enterHistorySelection(workout.id)
          : null,
      onShowOnMap: !forHistory &&
              widget.onShowRouteOnMap != null &&
              !_historySelectionMode
          ? () => widget.onShowRouteOnMap!(workout)
          : null,
      stats: extraStats.length > 3 ? extraStats.sublist(0, 3) : extraStats,
    );
  }

  void _enterHistorySelection(String workoutId) {
    setState(() {
      _historySelectionMode = true;
      _selectedWorkoutIds
        ..clear()
        ..add(workoutId);
    });
  }

  void _toggleHistorySelectionMode() {
    setState(() {
      if (_historySelectionMode) {
        _historySelectionMode = false;
        _selectedWorkoutIds.clear();
      } else {
        _historySelectionMode = true;
      }
    });
  }

  void _toggleWorkoutSelection(String workoutId, bool selected) {
    setState(() {
      if (selected) {
        _selectedWorkoutIds.add(workoutId);
      } else {
        _selectedWorkoutIds.remove(workoutId);
      }
    });
  }

  void _toggleSelectAllWorkouts(bool? value) {
    setState(() {
      if (value == true) {
        _selectedWorkoutIds
          ..clear()
          ..addAll(_workouts.map((workout) => workout.id));
      } else {
        _selectedWorkoutIds.clear();
      }
    });
  }

  bool? get _allWorkoutsSelected {
    if (_workouts.isEmpty || _selectedWorkoutIds.isEmpty) return false;
    if (_selectedWorkoutIds.length == _workouts.length) return true;
    return null;
  }

  Future<void> _deleteSelectedWorkouts() async {
    if (_selectedWorkoutIds.isEmpty || _workoutsDeleting) return;

    final count = _selectedWorkoutIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить маршруты?'),
        content: Text(
          count == 1
              ? 'Маршрут будет удалён с устройства без возможности восстановления.'
              : 'Будет удалено маршрутов: $count. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final targets = _workouts
        .where((workout) => _selectedWorkoutIds.contains(workout.id))
        .toList();
    final selectedIds = Set<String>.from(_selectedWorkoutIds);

    setState(() => _workoutsDeleting = true);

    var deleted = 0;
    try {
      deleted = await _gpxWorkoutService.deleteWorkouts(targets);

      if (!mounted) return;
      setState(() {
      if (deleted > 0) {
        _workouts.removeWhere((workout) => selectedIds.contains(workout.id));
      } else {
        // Убираем из списка локальные маршруты, даже если сервер не ответил.
        _workouts.removeWhere(
          (workout) =>
              selectedIds.contains(workout.id) && workout.filePath.isNotEmpty,
        );
      }
        _historySelectionMode = false;
        _selectedWorkoutIds.clear();
      });

      GpxWorkoutService.invalidateMemoryCache(notify: false);
      await _loadWorkouts(force: true);

      if (!mounted) return;
      if (deleted == 0) {
        AppSnackBar.show(context, 'Не удалось удалить маршруты');
      } else {
        AppSnackBar.show(
          context,
          deleted == 1 ? 'Маршрут удалён' : 'Удалено маршрутов: $deleted',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Ошибка удаления: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _workoutsDeleting = false);
      }
    }
  }

  Widget _buildHistorySelectionBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: profileElevatedDecoration(
        backgroundColor: ProfileColors.cardBg,
        radius: 12,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              tristate: true,
              value: _allWorkoutsSelected,
              activeColor: ProfileColors.primaryGreen,
              onChanged: _workoutsDeleting ? null : _toggleSelectAllWorkouts,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedWorkoutIds.isEmpty
                  ? 'Выделить все'
                  : 'Выбрано: ${_selectedWorkoutIds.length}',
              style: profileSubtitleStyle(),
            ),
          ),
          TextButton.icon(
            onPressed: _selectedWorkoutIds.isEmpty || _workoutsDeleting
                ? null
                : _deleteSelectedWorkouts,
            icon: _workoutsDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline, size: 18),
            label: Text(
              _selectedWorkoutIds.isEmpty
                  ? 'Удалить'
                  : 'Удалить (${_selectedWorkoutIds.length})',
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE53935),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsTab() {
    if (!_achievementsLoadedOrLoading()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAchievements());
    }

    if (_achievementsLoading && _achievements.isEmpty) {
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
            final context = _allAchievementsKey.currentContext;
            if (context != null) {
              Scrollable.ensureVisible(
                context,
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
              'Пока нет достижений. Завершите тренировку, чтобы получить первое!',
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
              .map((status) => _buildAchievementBadge(status, showHighlight: true))
              .toList(),
        ),
      ],
    );
  }

  bool _achievementsLoadedOrLoading() =>
      _achievements.isNotEmpty || _achievementsLoading;

  Widget _buildAchievementBadge(
    AchievementStatus status, {
    bool showHighlight = false,
  }) {
    return GestureDetector(
      onTap: () => _showAchievementDetails(status),
      child: AchievementBadge(
        icon: status.definition.icon,
        label: status.definition.title,
        locked: !status.unlocked,
        highlighted: showHighlight && status.isNew,
      ),
    );
  }

  void _showAchievementDetails(AchievementStatus status) {
    AchievementDetailsSheet.show(context, status: status);
  }

  Widget _buildHistoryTab() {
    if (!_workoutsLoaded && !_workoutsLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadWorkouts());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'История активности',
                style: profileSectionTitleStyle(),
              ),
            ),
            if (_workouts.isNotEmpty)
              TextButton(
                onPressed: _workoutsDeleting ? null : _toggleHistorySelectionMode,
                child: Text(
                  _historySelectionMode ? 'Готово' : 'Выбрать',
                  style: profileLinkStyle(),
                ),
              ),
          ],
        ),
        if (_historySelectionMode && _workouts.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildHistorySelectionBar(),
        ],
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
          _buildHistorySections(),
      ],
    );
  }

  Widget _buildHistorySections() {
    final myWorkouts = _myWorkouts;
    final importedWorkouts = _importedWorkouts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (myWorkouts.isNotEmpty) ...[
          const ProfileSectionHeader(title: 'Мои тренировки'),
          const SizedBox(height: 12),
          ...myWorkouts.map(
            (workout) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildWorkoutActivityCard(workout, forHistory: true),
            ),
          ),
        ],
        if (importedWorkouts.isNotEmpty) ...[
          if (myWorkouts.isNotEmpty) const SizedBox(height: 12),
          const ProfileSectionHeader(title: 'Скачанные из чатов'),
          const SizedBox(height: 12),
          ...importedWorkouts.map(
            (workout) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildWorkoutActivityCard(workout, forHistory: true),
            ),
          ),
        ],
      ],
    );
  }
}
