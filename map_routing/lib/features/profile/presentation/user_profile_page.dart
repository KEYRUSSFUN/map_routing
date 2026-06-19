import 'dart:async';

import 'package:flutter/material.dart';
import 'package:map_routing/core/navigation/app_route_observer.dart';
import 'package:map_routing/data/models/achievement.dart';
import 'package:map_routing/data/services/achievement_service.dart';
import 'package:map_routing/data/services/statistics_service.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';
import 'package:map_routing/features/profile/widgets/achievement_details_sheet.dart';

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

  double? distance;
  int? steps;
  double? calories;
  String? _weekChangeLabel;
  List<double>? _weeklyActivityData;
  bool _weeklyStatsLoading = false;

  bool isLoading = true;
  ProfileTab _selectedTab = ProfileTab.statistics;

  List<AchievementStatus> _achievements = [];
  bool _achievementsLoading = false;
  final _allAchievementsKey = GlobalKey();

  final userService = UserService();
  final statisticsService = StatisticsService();
  final _achievementService = AchievementService();

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

  Future<void> _loadAchievements({bool force = false}) async {
    if (_achievementsLoading) return;
    if (!force && _achievements.isNotEmpty) return;

    setState(() => _achievementsLoading = true);

    try {
      final achievements =
          await _achievementService.fetchForUser(userId: widget.userId);
      if (!mounted) return;
      setState(() {
        _achievements = achievements;
        _achievementsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _achievementsLoading = false);
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
          icon: Icons.directions_run,
          label: distance != null && distance! > 0
              ? '${distance!.toStringAsFixed(1)} км'
              : '-- км',
        ),
        ProfileStatPillData(
          icon: Icons.terrain,
          label: steps != null && steps! > 0 ? '$steps шагов' : '-- шагов',
        ),
        ProfileStatPillData(
          icon: Icons.emoji_events_outlined,
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
              statPills: _statPills,
              onBack: () => Navigator.pop(context),
            ),
            ProfileTabBar(
              selected: _selectedTab,
              onChanged: (tab) {
                setState(() => _selectedTab = tab);
                if (tab == ProfileTab.achievements && _achievements.isEmpty) {
                  unawaited(_loadAchievements());
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
        return _buildEmptyTab(
          'История активности этого пользователя пока недоступна',
        );
    }
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
        const ProfileSectionHeader(title: 'Личные рекорды'),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Рекорды пользователя пока не отображаются.',
            style: profileSubtitleStyle(),
          ),
        ),
      ],
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

  bool _achievementsLoadedOrLoading() =>
      _achievements.isNotEmpty || _achievementsLoading;

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
