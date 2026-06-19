import 'dart:async';

import 'package:common/resources/theme.dart';
import 'package:flutter/material.dart';
import 'package:map_routing/core/map/mapkit_bootstrap.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/core/widgets/stride_track_logo.dart';
import 'package:map_routing/core/theme/app_theme.dart';
import 'package:map_routing/core/widgets/app_bottom_nav_bar.dart';
import 'package:map_routing/features/auth/presentation/login_page.dart';
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/data/services/socket_chat_service.dart';
import 'package:map_routing/features/chat/presentation/group_chats_page.dart';
import 'package:map_routing/features/home/home_page_controller.dart';
import 'package:map_routing/features/home/presentation/home_page.dart';
import 'package:map_routing/features/profile/presentation/profile.dart';
import 'package:map_routing/features/auth/presentation/start_page.dart';
import 'package:map_routing/features/map/presentation/map_screen.dart';
import 'package:map_routing/data/models/planned_workout.dart';
import 'package:map_routing/data/models/workout_summary.dart';
import 'package:map_routing/data/services/planned_workout_service.dart';
import 'package:map_routing/core/services/notification_service.dart';
import 'package:map_routing/data/services/app_settings_service.dart';
import 'package:map_routing/data/services/gpx_workout_service.dart';
import 'package:map_routing/data/services/community_list_cache.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';
import 'package:map_routing/data/models/chat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/features/auth/data/token_verify.dart';
import 'package:map_routing/features/chat/presentation/chat_screen_page.dart';
import 'package:map_routing/core/navigation/app_route_observer.dart';

export 'package:map_routing/core/navigation/app_route_observer.dart'
    show appRouteObserver;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(AppSettingsService.instance.ensureLoaded());

  runApp(
    MaterialApp(
      title: 'StrideTrack',
      theme: AppTheme.lightTheme,
      darkTheme: MapkitFlutterTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return AppSnackBarHost(child: child);
      },
      navigatorObservers: [
        appRouteObserver,
        chatRouteObserver,
        chatListRouteObserver,
      ],
      home: const _AppBootstrap(),
      routes: {
        '/start_page': (context) => const StartPage(),
        '/home': (context) => const MapkitFlutterApp(),
        '/login_page': (context) => const LoginPage(),
        '/profile_page': (context) => const ProfilePage(),
      },
    ),
  );
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  _BootstrapPhase _phase = _BootstrapPhase.loading;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final prefsFuture = SharedPreferences.getInstance();
      final fontsFuture = _preloadUiFonts();

      final prefs = await prefsFuture;
      await fontsFuture;

      unawaited(MapkitBootstrap.ensureInitialized());

      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _phase = _BootstrapPhase.unauthenticated);
        return;
      }

      if (mounted) setState(() => _phase = _BootstrapPhase.authenticated);

      unawaited(UserWorkoutStorage.instance.syncUserIdFromToken(token));

      final valid = await TokenVerify.ensureValidSession();
      if (!valid && mounted) {
        setState(() => _phase = _BootstrapPhase.unauthenticated);
      }
    } catch (_) {
      if (mounted) setState(() => _phase = _BootstrapPhase.unauthenticated);
    }
  }

  static Future<void> _preloadUiFonts() {
    return GoogleFonts.pendingFonts([
      GoogleFonts.lexendDeca(fontWeight: FontWeight.w400),
      GoogleFonts.lexendDeca(fontWeight: FontWeight.w600),
      GoogleFonts.lexendDeca(fontWeight: FontWeight.w700),
      GoogleFonts.lexendDeca(fontWeight: FontWeight.w800),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _BootstrapPhase.loading => const StrideTrackSplash(),
      _BootstrapPhase.authenticated => const MapkitFlutterApp(),
      _BootstrapPhase.unauthenticated => const StartPage(),
    };
  }
}

enum _BootstrapPhase { loading, authenticated, unauthenticated }

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
  bool _libraryRefreshPending = false;
  final Set<int> _mountedTabs = {0};
  final List<Widget?> _cachedTabChildren = List.filled(4, null);

  void _onMapWorkoutSaved() {
    profilePageKey.currentState?.refreshData(force: true);
  }

  void _mapWorkoutUiChanged({
    required bool isActive,
    required bool isFullscreen,
  }) {
    _onWorkoutUiChanged(isActive: isActive, isFullscreen: isFullscreen);
  }

  Future<void> _handleGlobalChatDeleted(dynamic raw) async {
    final page = groupChatsPageKey.currentState;
    if (page != null) {
      page.handleRemoteChatDeleted(raw);
      return;
    }

    if (raw is! Map) return;
    final chatId = raw['chat_id']?.toString();
    if (chatId == null || chatId.isEmpty) return;

    final userId = await UserWorkoutStorage.instance.getStoredUserId();
    if (userId != null) {
      await CommunityListCache.instance.removeChat(
        userId: userId,
        chatId: chatId,
      );
    }
  }

  Future<void> _handleGlobalChatAdded(dynamic raw) async {
    final page = groupChatsPageKey.currentState;
    if (page != null) {
      page.handleRemoteChatAdded(raw);
      return;
    }

    if (raw is! Map) return;
    final chatRaw = raw['chat'];
    if (chatRaw is! Map) return;

    final userId = await UserWorkoutStorage.instance.getStoredUserId();
    if (userId == null) return;

    final chat = Chat.fromJson(Map<String, dynamic>.from(chatRaw));
    if (chat.id.isEmpty) return;

    await CommunityListCache.instance.addChat(userId: userId, chat: chat);
  }

  Future<void> _handleGlobalChatUpdated(dynamic raw) async {
    final page = groupChatsPageKey.currentState;
    if (page != null) {
      page.handleRemoteChatUpdated(raw);
    }
  }

  Future<void> _handleGlobalPresenceUpdate(dynamic raw) async {
    if (raw is! Map) return;
    final userId = raw['user_id']?.toString();
    if (userId == null || userId.isEmpty) return;
    final isOnline = raw['is_online'] == true;

    HomePageController.instance.updatePresence(userId, isOnline);
    groupChatsPageKey.currentState?.handlePresenceUpdate(raw);
  }

  Future<void> _bootstrapRealtime() async {
    SocketChatService.instance.ensureGlobalHandlers(
      onChatDeleted: _handleGlobalChatDeleted,
      onChatAdded: _handleGlobalChatAdded,
      onChatUpdated: _handleGlobalChatUpdated,
      onPresenceUpdate: _handleGlobalPresenceUpdate,
    );
    await SocketChatService.instance.ensureConnected(backendBaseUrl);
    SocketChatService.instance.joinUserRoom();
  }

  @override
  void initState() {
    super.initState();
    _gpxPath = widget.initialGpxPath;
    if (_gpxPath != null) {
      _selectedNavIndex = 1;
      _stackIndex = 1;
      _mountedTabs.add(1);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GpxWorkoutService.onLibraryChanged = () {
        if (_libraryRefreshPending) return;
        _libraryRefreshPending = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _libraryRefreshPending = false;
          profilePageKey.currentState?.refreshData(force: true);
        });
      };
      HomePageController.instance.bindOpenProfileChallenges(openProfileChallenges);
      Future<void>.delayed(const Duration(seconds: 2), () async {
        if (!mounted) return;
        NotificationService.instance.onPayloadTap = (payload) {
          unawaited(_openPlannedWorkoutFromPayload(payload));
        };
        await NotificationService.instance.init();
        final userId = await UserWorkoutStorage.instance.getStoredUserId();
        if (userId != null) {
          unawaited(
            PlannedWorkoutService.instance.rescheduleAllNotifications(userId),
          );
        }
        unawaited(_bootstrapRealtime());
      });
    });
  }

  @override
  void dispose() {
    GpxWorkoutService.onLibraryChanged = null;
    super.dispose();
  }

  void _mountTab(int stackIndex) {
    _mountedTabs.add(stackIndex);
  }

  Widget _createTabOnce(int stackIndex) {
    switch (stackIndex) {
      case 0:
        return const RepaintBoundary(child: HomePage());
      case 1:
        return RepaintBoundary(
          child: MapScreen(
            key: mapScreenKey,
            gpxPath: _gpxPath,
            isTabActive: _stackIndex == 1,
            bottomNavPadding: _stackIndex == 1 ? _currentNavPadding : 0,
            onWorkoutUiChanged: _mapWorkoutUiChanged,
            onWorkoutSaved: _onMapWorkoutSaved,
          ),
        );
      case 2:
        return RepaintBoundary(child: GroupChatsPage(key: groupChatsPageKey));
      case 3:
        return RepaintBoundary(
          child: ProfilePage(
            key: profilePageKey,
            onShowRouteOnMap: showWorkoutRouteOnMap,
            onOpenPlannedWorkout: showPlannedWorkoutOnMap,
          ),
        );
      default:
        return _tabPlaceholder(stackIndex);
    }
  }

  Widget _tabPlaceholder(int stackIndex) {
    return ColoredBox(
      key: ValueKey('tab_placeholder_$stackIndex'),
      color: stackIndex == 0
          ? const Color(0xFFF7F7F7)
          : const Color(0xFFF2F5F7),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildStackChild(int stackIndex) {
    if (!_mountedTabs.contains(stackIndex)) {
      return _tabPlaceholder(stackIndex);
    }

    if (stackIndex == 1) {
      return _createTabOnce(1);
    }

    return _cachedTabChildren[stackIndex] ??= _createTabOnce(stackIndex);
  }

  double _currentNavPadding = 0;

  int _stackIndexForNav(int navIndex) {
    if (navIndex <= 1) return navIndex;
    return navIndex - 1;
  }

  void _onWorkoutUiChanged({
    required bool isActive,
    required bool isFullscreen,
  }) {
    if (_workoutActive == isActive && _workoutFullscreen == isFullscreen) {
      return;
    }
    setState(() {
      _workoutActive = isActive;
      _workoutFullscreen = isFullscreen;
      if (isActive) _mountedTabs.add(1);
    });
  }

  void _onItemTapped(int navIndex) {
    if (navIndex == 2) {
      _startWorkout();
      return;
    }

    final stackIndex = _stackIndexForNav(navIndex);
    setState(() {
      _mountTab(stackIndex);
      _selectedNavIndex = navIndex;
      _stackIndex = stackIndex;
      if (navIndex != 1) _gpxPath = null;
    });

    if (navIndex == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        profilePageKey.currentState?.refreshData();
      });
    }
    if (navIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HomePageController.instance.refresh(force: true);
      });
    }
    if (navIndex == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        groupChatsPageKey.currentState?.loadDataIfStale(
          silent: true,
          showSyncIndicator: false,
        );
      });
    }
  }

  void _startWorkout() {
    setState(() {
      _mountTab(1);
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
      _mountTab(1);
      _selectedNavIndex = 1;
      _stackIndex = 1;
    });
    mapScreenKey.currentState?.expandWorkout();
  }

  void showWorkoutRouteOnMap(WorkoutSummary workout) {
    setState(() {
      _mountTab(1);
      _selectedNavIndex = 1;
      _stackIndex = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      mapScreenKey.currentState?.loadSavedRoute(workout);
    });
  }

  void showPlannedWorkoutOnMap(PlannedWorkout workout) {
    setState(() {
      _mountTab(1);
      _selectedNavIndex = 1;
      _stackIndex = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      mapScreenKey.currentState?.loadPlannedWorkout(workout);
    });
  }

  Future<void> _openPlannedWorkoutFromPayload(String payload) async {
    if (!payload.startsWith('planned_workout:')) return;
    final workoutId = payload.substring('planned_workout:'.length);
    if (workoutId.isEmpty) return;

    final userId = await UserWorkoutStorage.instance.getStoredUserId();
    if (userId == null) return;

    final workout =
        await PlannedWorkoutService.instance.findById(userId, workoutId);
    if (workout == null || !mounted) return;
    showPlannedWorkoutOnMap(workout);
  }

  void openProfileChallenges() {
    setState(() {
      _mountTab(3);
      _selectedNavIndex = 4;
      _stackIndex = 3;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      profilePageKey.currentState?.scrollToChallenges();
    });
  }

  bool get _hideBottomNav => _workoutFullscreen;

  bool _isKeyboardOpen(BuildContext context) {
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio > 0;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOnMap = _stackIndex == 1 && _isKeyboardOpen(context);
    final hideBottomNav = _hideBottomNav || keyboardOnMap;
    final navPadding = hideBottomNav
        ? 0.0
        : AppBottomNavBar.scrollEndPadding(context);

    _currentNavPadding = navPadding;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _stackIndex,
        sizing: StackFit.expand,
        children: List.generate(4, _buildStackChild),
      ),
      bottomNavigationBar: hideBottomNav
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
