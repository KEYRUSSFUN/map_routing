import 'package:flutter/material.dart';
import 'package:map_routing/core/navigation/app_route_observer.dart';
import 'package:map_routing/data/services/statistics_service.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

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
  late Future<List<double>> weeklyActivityDataFuture;

  bool isLoading = true;
  ProfileTab _selectedTab = ProfileTab.statistics;

  final userService = UserService();
  final statisticsService = StatisticsService();

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
    });
  }

  Future<void> fetchStatistics() async {
    try {
      final summary =
          await statisticsService.fetchAllWeeklyStats(userId: widget.userId);
      final rawData =
          await statisticsService.fetchWeeklyStats(userId: widget.userId);
      final weekChange = await statisticsService.fetchWeekOverWeekChangePercent(
        userId: widget.userId,
      );

      final distancePerDay =
          rawData.map((day) => (day['distance'] as double?) ?? 0.0).toList();

      if (!mounted) return;

      setState(() {
        distance = summary.distanceKm;
        steps = summary.steps;
        calories = summary.calories;
        _weekChangeLabel =
            StatisticsService.formatWeekChangeLabel(weekChange);
        weeklyActivityDataFuture = Future.value(distancePerDay);
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        distance = 0;
        steps = 0;
        calories = 0;
        _weekChangeLabel = 'Нет данных';
        weeklyActivityDataFuture = Future.value(const [0, 0, 0, 0, 0, 0, 0]);
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    weeklyActivityDataFuture = Future.value(const []);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    await fetchUserInfo();
    await fetchStatistics();
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
    _loadData();
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
    if (isLoading) {
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
              onChanged: (tab) => setState(() => _selectedTab = tab),
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
        return _buildEmptyTab(
          'Достижения пользователя пока недоступны',
        );
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
          weeklyDataFuture: weeklyActivityDataFuture,
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
