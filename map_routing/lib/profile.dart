import 'package:flutter/material.dart';
import 'package:map_routing/usersData/statistics_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:map_routing/edit_profile.dart';
import 'package:map_routing/gpx_route_list_page.dart';
import 'package:map_routing/usersData/user_service.dart';
import 'package:map_routing/usersData/friend_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

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
  int? steps; // Changed from time to steps
  double? calories;

  bool isLoading = true;

  final userService = UserService();
  final statisticsService = StatisticsService();
  FriendService? friendService;

  void refreshData() {
    fetchUserInfo();
    fetchStatistics();
    fetchFriendRequests();
  }

  void fetchStatistics() async {
    final summary = await statisticsService.fetchAllWeeklyStats();
    final rawData = await statisticsService.fetchWeeklyStats();

    final List<double> distancePerDay =
        rawData.map((day) => (day['distance'] as double?) ?? 0.0).toList();

    if (!mounted) return;

    setState(() {
      distance = summary.distanceKm;
      steps = summary.steps; // Changed from time to steps
      calories = summary.calories;
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
      country = data['country'] ?? 'Нет страны';
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
      print('Error fetching friend requests: $e');
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запрос принят')),
      );
    } catch (e) {
      print('Error accepting friend request: $e');
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запрос отклонён')),
      );
    } catch (e) {
      print('Error rejecting friend request: $e');
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
    });
  }

  Future<void> _initializeFriendService() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      print('No token found in SharedPreferences');
      return;
    }
    setState(() {
      friendService =
          FriendService(baseUrl: 'http://192.168.1.105:5000', token: token);
    });
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
    fetchFriendRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/start_page'),
        ),
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
                                        userAvatarUrl.isNotEmpty
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
                                "Шаги", // Changed from "Время" to "Шаги"
                                steps != null
                                    ? "$steps шагов" // Display steps as integer
                                    : "-- шагов"),
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
                        const Text(
                          "Запросы на дружбу",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: friendRequestsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Text("Нет новых запросов");
                            }
                            final requests = snapshot.data!;
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: requests.length,
                              itemBuilder: (context, index) {
                                final request = requests[index];
                                print(request);
                                return ListTile(
                                  leading: const Icon(Icons.person_add),
                                  title: Text(request['fromUserName'] ??
                                      'Неизвестный пользователь'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check,
                                            color: Colors.green),
                                        onPressed: () => acceptFriendRequest(
                                            request['fromUserId']),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            color: Color.fromARGB(
                                                255, 252, 252, 252)),
                                        onPressed: () => rejectFriendRequest(
                                            request['fromUserId']),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
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

  List<String> _getDayLabels() {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 7));
    final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return List.generate(7, (index) {
      final date = startDate.add(Duration(days: index));
      return days[date.weekday % 7];
    });
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
        final maxY = _getMaxY(weeklyData);
        final dayLabels = _getDayLabels();
        return LineChart(
          LineChartData(
            backgroundColor: const Color.fromARGB(255, 250, 250, 250),
            minY: 0,
            maxY: maxY,
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < weeklyData.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          dayLabels[index],
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: maxY / 2,
                  getTitlesWidget: (value, meta) {
                    if (value == 0 || value == maxY || value == maxY / 2) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.black87),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  weeklyData.length,
                  (i) => FlSpot(i.toDouble(),
                      double.parse(weeklyData[i].toStringAsFixed(2))),
                ),
                isCurved: false,
                color: const Color(0xFF3490DE),
                barWidth: 2,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF3490DE).withOpacity(0.2),
                ),
              ),
            ],
            gridData: FlGridData(
              show: true,
              horizontalInterval: maxY / 2,
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
