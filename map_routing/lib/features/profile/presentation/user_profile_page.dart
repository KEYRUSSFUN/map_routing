import 'package:flutter/material.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/core/navigation/app_route_observer.dart';
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

  bool isLoading = true;
  ProfileTab _selectedTab = ProfileTab.statistics;

  final userService = UserService();

  void fetchUserInfo() async {
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
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    fetchUserInfo();
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
    fetchUserInfo();
  }

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
              location: country,
              subtitle: 'Спортсмен',
              avatarUrl: userAvatarUrl.isNotEmpty ? userAvatarUrl : null,
              statPills: const [
                ProfileStatPillData(
                  icon: Icons.directions_run,
                  label: '42.5 км',
                ),
                ProfileStatPillData(
                  icon: Icons.terrain,
                  label: '12 ч',
                ),
                ProfileStatPillData(
                  icon: Icons.emoji_events_outlined,
                  label: '14 дней',
                ),
              ],
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
          weeklyDataFuture:
              Future.value(const [3.2, 5.1, 4.0, 6.8, 2.5, 7.2, 4.6]),
          totalLabel: 'Всего: 33.4 км',
          changeLabel: '+12% к прошлой неделе',
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
        const ActivityCard(
          title: 'Утренний трейлран',
          subtitle: 'Вчера в 6:15',
          stats: [
            ActivityStat(value: '12.4 км', label: 'Дистанция'),
            ActivityStat(value: '1 ч 05 м', label: 'Время'),
            ActivityStat(value: "5'14''", label: 'Средний темп'),
          ],
        ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionHeader(title: 'История активности'),
        const SizedBox(height: 12),
        const ActivityCard(
          title: 'Утренний трейлран',
          subtitle: 'Вчера в 8:15',
          stats: [
            ActivityStat(value: '12 км', label: 'Дистанция'),
            ActivityStat(value: '1 ч 0 м', label: 'Время'),
            ActivityStat(value: "5'14''", label: 'Средний темп'),
          ],
        ),
        const SizedBox(height: 12),
        const ActivityCard(
          title: 'Прибрежная поездка',
          subtitle: '20 окт. 2023',
          icon: Icons.directions_bike,
          stats: [
            ActivityStat(value: '45.2 км', label: 'Дистанция'),
            ActivityStat(value: '1 ч 52 м', label: 'Время'),
            ActivityStat(value: '24.2 км/ч', label: 'Средняя скорость'),
          ],
        ),
      ],
    );
  }
}
