import 'package:common/resources/theme.dart';
import 'package:flutter/material.dart';
import 'package:map_routing/core/widgets/stride_track_logo.dart';
import 'package:map_routing/core/theme/app_theme.dart';
import 'package:map_routing/core/widgets/app_bottom_nav_bar.dart';
import 'package:map_routing/features/auth/presentation/login_page.dart';
import 'package:map_routing/features/chat/presentation/group_chats_page.dart';
import 'package:map_routing/features/home/presentation/home_page.dart';
import 'package:map_routing/features/profile/presentation/profile.dart';
import 'package:map_routing/features/auth/presentation/start_page.dart';
import 'package:map_routing/features/map/presentation/map_screen.dart';
import 'package:map_routing/core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yandex_maps_mapkit/init.dart' as init;
import 'package:map_routing/features/auth/data/token_verify.dart';
import 'package:map_routing/features/chat/presentation/chat_screen_page.dart';
import 'package:map_routing/core/navigation/app_route_observer.dart';

export 'package:map_routing/core/navigation/app_route_observer.dart'
    show appRouteObserver;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  init.initMapkit(apiKey: '548e7748-56df-4316-844a-fa548260d146');
  await NotificationService.instance.init();

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  runApp(MaterialApp(
    title: 'StrideTrack',
    theme: AppTheme.lightTheme,
    darkTheme: MapkitFlutterTheme.darkTheme,
    themeMode: ThemeMode.system,
    navigatorObservers: [
      appRouteObserver,
      chatRouteObserver,
      chatListRouteObserver,
    ],
    home: FutureBuilder<String?>(
      future: getToken(),
      builder: (BuildContext context, AsyncSnapshot<String?> tokenSnapshot) {
        if (tokenSnapshot.connectionState == ConnectionState.waiting) {
          return const StrideTrackSplash();
        } else if (tokenSnapshot.hasError) {
          return Scaffold(
              body: Center(child: Text('Ошибка: ${tokenSnapshot.error}')));
        } else {
          final token = tokenSnapshot.data;

          return FutureBuilder<bool>(
            future: TokenVerify(token: token ?? '').isTokenValidOnServer(),
            builder:
                (BuildContext context, AsyncSnapshot<bool> isValidSnapshot) {
              if (isValidSnapshot.connectionState == ConnectionState.waiting) {
                return const StrideTrackSplash();
              } else if (isValidSnapshot.hasError) {
                return Scaffold(
                    body: Center(
                        child: Text('Ошибка: ${isValidSnapshot.error}')));
              } else {
                final isValid = isValidSnapshot.data ?? false;

                if (isValid) {
                  return const MapkitFlutterApp();
                } else {
                  return const StartPage();
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
      '/profile_page': (context) => const ProfilePage()
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
      GlobalKey<GroupChatsPageState>();

  final GlobalKey<MapScreenState> mapScreenKey = GlobalKey<MapScreenState>();

  int _selectedNavIndex = 0;
  int _stackIndex = 0;
  String? _gpxPath;

  bool _workoutActive = false;
  bool _workoutFullscreen = false;

  @override
  void initState() {
    super.initState();
    _gpxPath = widget.initialGpxPath;
    if (_gpxPath != null) {
      _selectedNavIndex = 1;
      _stackIndex = 1;
    }
  }

  int _stackIndexForNav(int navIndex) {
    if (navIndex <= 1) return navIndex;
    return navIndex - 1;
  }

  void _onWorkoutUiChanged(
      {required bool isActive, required bool isFullscreen}) {
    setState(() {
      _workoutActive = isActive;
      _workoutFullscreen = isFullscreen;
    });
  }

  void _onItemTapped(int navIndex) {
    if (navIndex == 2) {
      _startWorkout();
      return;
    }

    setState(() {
      _selectedNavIndex = navIndex;
      _stackIndex = _stackIndexForNav(navIndex);
      if (navIndex != 1) _gpxPath = null;
    });

    if (navIndex == 4) profilePageKey.currentState?.refreshData();
    if (navIndex == 3) groupChatsPageKey.currentState?.loadData(silent: true);
  }

  void _startWorkout() {
    setState(() {
      _selectedNavIndex = 1;
      _stackIndex = 1;
      _gpxPath = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      mapScreenKey.currentState?.startTracking();
    });
  }

  void _returnToWorkout() {
    setState(() {
      _selectedNavIndex = 1;
      _stackIndex = 1;
    });
    mapScreenKey.currentState?.expandWorkout();
  }

  bool get _hideBottomNav => _workoutFullscreen;

  @override
  Widget build(BuildContext context) {
    final navPadding =
        _hideBottomNav ? 0.0 : AppBottomNavBar.scrollEndPadding(context);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _stackIndex,
        sizing: StackFit.expand,
        children: [
          RepaintBoundary(child: const HomePage()),
          RepaintBoundary(
            child: MapScreen(
              key: mapScreenKey,
              gpxPath: _gpxPath,
              isTabActive: _stackIndex == 1,
              bottomNavPadding: navPadding,
              onWorkoutUiChanged: _onWorkoutUiChanged,
              onWorkoutSaved: () => profilePageKey.currentState?.refreshData(),
            ),
          ),
          RepaintBoundary(child: GroupChatsPage(key: groupChatsPageKey)),
          RepaintBoundary(child: ProfilePage(key: profilePageKey)),
        ],
      ),
      bottomNavigationBar: _hideBottomNav
          ? null
          : AppBottomNavBar(
              selectedIndex: _selectedNavIndex,
              onItemSelected: _onItemTapped,
              onStartWorkout: _startWorkout,
              showWorkoutBanner:
                  _workoutActive && !_workoutFullscreen && _stackIndex != 1,
              onReturnToWorkout: _returnToWorkout,
            ),
    );
  }
}
