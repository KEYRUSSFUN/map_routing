import 'package:flutter/material.dart';

import 'package:map_routing/usersData/statistics_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:map_routing/edit_profile.dart';
import 'package:map_routing/gpx_route_list_page.dart';
import 'package:map_routing/usersData/user_service.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> with RouteAware {
  late Future<List<double>> weeklyActivityDataFuture;

  String name = '';
  String country = '';
  String userAvatarUrl = '';

  double? distance;
  int? time;
  double? calories;

  bool isLoading = true;

  final userService = UserService();
  final statisticsService = StatisticsService();

  void refreshData() {
    fetchUserInfo();
    fetchStatistics();
  }

  void fetchStatistics() async {
    final summary = await statisticsService.fetchAllWeeklyStats();
    final rawData = await statisticsService.fetchWeeklyStats();

    final List<double> distancePerDay =
        rawData.map((day) => (day['distance'] as double?) ?? 0.0).toList();

    if (!mounted) return;

    setState(() {
      distance = summary.distanceKm;
      time = summary.activeTimeSec;
      calories = summary.calories;
      weeklyActivityDataFuture = Future.value(distancePerDay); // 👈 здесь
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
      country = data['country'] ?? 'Нет страны';
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    weeklyActivityDataFuture = Future.value([]);
    fetchUserInfo();
    fetchStatistics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    fetchStatistics();
    fetchUserInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Профиль"),
        surfaceTintColor: Colors.white,
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color.fromARGB(255, 255, 255, 255),
            height: 1.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // переход к настройкам
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const EditProfilePage()),
                                );
                              },
                              child: CircleAvatar(
                                radius: 40,
                                backgroundImage: userAvatarUrl != null &&
                                        userAvatarUrl!.isNotEmpty
                                    ? NetworkImage(userAvatarUrl)
                                    : const AssetImage(
                                            'assets/images/profile.png')
                                        as ImageProvider,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  country,
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _buildStat("Подписки", "0"),
                            const SizedBox(width: 20),
                            _buildStat("Подписчики", "0"),
                            const SizedBox(width: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(thickness: 10, color: Colors.grey[200]),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "На этой неделе",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildWeeklyStat(
                                "Расстояние",
                                distance != null
                                    ? "${distance!.toStringAsFixed(1)} км"
                                    : "-- км"),
                            _buildWeeklyStat(
                                "Время",
                                time != null
                                    ? "${(time! ~/ 3600)} ч ${(time! % 3600) ~/ 60} м"
                                    : "-- ч"),
                            _buildWeeklyStat(
                                "Калории",
                                calories != null
                                    ? "${calories!.toStringAsFixed(0)} ккал"
                                    : "--"),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          height: 200,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: WeeklyActivityChart(
                              key: ValueKey(weeklyActivityDataFuture),
                              weeklyDataFuture: weeklyActivityDataFuture),
                        ),
                      ],
                    ),
                  ),
                  Divider(thickness: 10, color: Colors.grey[200]),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.watch),
                          title: const Text("Физическая активность"),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const ActivityPage()),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.auto_graph),
                          title: const Text("Статистика"),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const StatisticPage()),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.route),
                          title: const Text("Маршруты"),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const GpxRouteListPage()),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.watch_later),
                          title: const Text("Рекорды"),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const RecordsPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label),
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildWeeklyStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class WeeklyActivityChart extends StatefulWidget {
  final Future<List<double>> weeklyDataFuture;

  const WeeklyActivityChart({super.key, required this.weeklyDataFuture});

  @override
  State<WeeklyActivityChart> createState() => _WeeklyActivityChartState();
}

class _WeeklyActivityChartState extends State<WeeklyActivityChart> {
  late Future<List<double>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.weeklyDataFuture;
  }

  @override
  void didUpdateWidget(covariant WeeklyActivityChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weeklyDataFuture != widget.weeklyDataFuture) {
      setState(() {
        _future = widget.weeklyDataFuture;
      });
    }
  }

  double _getMaxY(List<double> data) {
    if (data.isEmpty) return 1.0;
    final max = data.reduce((a, b) => a > b ? a : b);
    return (max < 1.0) ? 1.0 : (max * 1.2).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<double>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final weeklyData = snapshot.data!;
        return LineChart(
          LineChartData(
            backgroundColor: const Color.fromARGB(255, 226, 5, 5),
            minY: 0,
            maxY: _getMaxY(weeklyData),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
                    return Text(days[value.toInt() % 7]);
                  },
                ),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  weeklyData.length,
                  (i) => FlSpot(i.toDouble(), weeklyData[i]),
                ),
                isCurved: true,
                color: Colors.blue,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.blue.withOpacity(0.2),
                ),
              ),
            ],
            gridData: FlGridData(
              show: true,
              horizontalInterval: 1,
              verticalInterval: 1,
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: Colors.grey[400]!, strokeWidth: 1),
              getDrawingVerticalLine: (value) =>
                  FlLine(color: Colors.grey[400]!, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
          ),
        );
      },
    );
  }
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Физическая активность")),
      body: const Center(child: Text("Список тренировок")),
    );
  }
}

class StatisticPage extends StatelessWidget {
  const StatisticPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Статистика")),
      body: const Center(child: Text("Статистика")),
    );
  }
}

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Рекорды")),
      body: const Center(child: Text("Рекорды")),
    );
  }
}
