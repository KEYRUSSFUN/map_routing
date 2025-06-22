import 'package:flutter/material.dart';
import 'package:map_routing/usersData/user_service.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

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

  final userService = UserService();

  void fetchUserInfo() async {
    final data = await userService.fetchOtherUserInfo(
        userId: widget.userId); // Загружаем данные по userId

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
    fetchUserInfo();
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
    fetchUserInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Профиль пользователя"),
        surfaceTintColor: Colors.white,
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color.fromARGB(255, 255, 255, 255),
            height: 1.0,
          ),
        ),
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
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: userAvatarUrl != null &&
                                      userAvatarUrl!.isNotEmpty
                                  ? NetworkImage(userAvatarUrl)
                                  : const AssetImage(
                                          'assets/images/profile.png')
                                      as ImageProvider,
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
}
