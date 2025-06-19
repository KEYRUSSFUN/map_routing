import 'package:common/resources/theme.dart';
import 'package:flutter/material.dart';
import 'package:map_routing/app_theme.dart';
import 'package:map_routing/aunth.dart';
import 'package:map_routing/group_chats_page.dart';
import 'package:map_routing/profile.dart';
import 'package:map_routing/start_page.dart';
import 'package:map_routing/map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yandex_maps_mapkit/init.dart' as init;
import 'tokenVerify.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //await dotenv.load(fileName: ".env");
  init.initMapkit(apiKey: "548e7748-56df-4316-844a-fa548260d146");

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  runApp(MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: MapkitFlutterTheme.darkTheme,
    themeMode: ThemeMode.system,
    navigatorObservers: [routeObserver],
    home: FutureBuilder<String?>(
      future: getToken(),
      builder: (BuildContext context, AsyncSnapshot<String?> tokenSnapshot) {
        if (tokenSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        } else if (tokenSnapshot.hasError) {
          return Scaffold(
              body: Center(child: Text('Ошибка: ${tokenSnapshot.error}')));
        } else {
          final token = tokenSnapshot.data;

          //Теперь у нас есть токен, и мы можем проверить его
          return FutureBuilder<bool>(
            future: TokenVerify(
                    token: token ?? '', baseUrl: 'http://192.168.1.81:5000')
                .isTokenValidOnServer(),
            // Вызываем функцию проверки токена на сервере
            builder:
                (BuildContext context, AsyncSnapshot<bool> isValidSnapshot) {
              if (isValidSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              } else if (isValidSnapshot.hasError) {
                return Scaffold(
                    body: Center(
                        child: Text('Ошибка: ${isValidSnapshot.error}')));
              } else {
                final isValid = isValidSnapshot.data ?? false;

                if (isValid) {
                  return const MapkitFlutterApp();
                } else {
                  return const LoginPage();
                }
              }
            },
          );
        }
      },
    ),
    routes: {
      '/start_page': (context) => const StartPage(),
      '/home': (context) => const MapkitFlutterApp(),
      '/login_page': (context) => const LoginPage(),
    },
  ));
}

class MapkitFlutterApp extends StatefulWidget {
  const MapkitFlutterApp({super.key, this.initialGpxPath});
  final String? initialGpxPath;

  @override
  State<MapkitFlutterApp> createState() => _MapkitFlutterAppState();
}

class _MapkitFlutterAppState extends State<MapkitFlutterApp> {
  final GlobalKey<ProfilePageState> profilePageKey =
      GlobalKey<ProfilePageState>();
  final GlobalKey<GroupChatsPageState> groupChatsPageKey =
      GlobalKey<GroupChatsPageState>(); // Исправляем тип ключа
  int _selectedIndex = 1;
  String? _gpxPath;

  @override
  void initState() {
    super.initState();
    _gpxPath = widget.initialGpxPath;
    _selectedIndex = 1;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index != 1) _gpxPath = null;
      if (index == 2) profilePageKey.currentState?.refreshData();
      if (index == 0)
        groupChatsPageKey.currentState
            ?.loadData(); // Вызываем loadData для GroupChatsPage
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      GroupChatsPage(key: groupChatsPageKey),
      MapScreen(gpxPath: _gpxPath),
      ProfilePage(key: profilePageKey),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Группы'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Карта'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
      ),
    );
  }
}
