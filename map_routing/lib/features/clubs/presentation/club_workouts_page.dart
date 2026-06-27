import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/models/club.dart';
import 'package:map_routing/data/services/club_service.dart';
import 'package:map_routing/data/services/gpx_workout_service.dart';
import 'package:map_routing/data/services/route_service.dart';
import 'package:map_routing/features/clubs/presentation/club_workout_card.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';
import 'package:map_routing/features/profile/presentation/workout_detail_page.dart';

class ClubWorkoutsPage extends StatefulWidget {
  const ClubWorkoutsPage({
    super.key,
    required this.clubService,
    required this.club,
  });

  final ClubService clubService;
  final ClubSummary club;

  @override
  State<ClubWorkoutsPage> createState() => _ClubWorkoutsPageState();
}

class _ClubWorkoutsPageState extends State<ClubWorkoutsPage> {
  final _gpxService = GpxWorkoutService();

  List<ClubMemberWorkout> _workouts = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkouts(reset: true);
  }

  Future<void> _loadWorkouts({bool reset = false}) async {
    if (_loading || _loadingMore) return;
    final nextPage = reset ? 1 : _page + 1;

    setState(() {
      _error = null;
      if (reset) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await widget.clubService.fetchWorkouts(
        clubId: widget.club.id,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _workouts = result.workouts;
        } else {
          _workouts = [..._workouts, ...result.workouts];
        }
        _page = result.page;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _openWorkout(ClubMemberWorkout item) async {
    final route = BackendRoute(
      id: item.routeId,
      path: item.path ?? const {},
      title: item.title,
      activityType: item.activityType,
      description: item.description,
      tags: item.tags,
      effortLevel: item.effortLevel,
      privacy: item.privacy,
      distanceMeters: item.distanceMeters,
      durationSeconds: item.durationSeconds,
      calories: item.calories,
      elevationGainM: item.elevationGainM,
      avgSpeedKmh: item.avgSpeedKmh,
      startedAt: item.startedAt,
      photoUrl: item.photoUrl,
    );

    final summary = _gpxService.parseBackendRoute(route);
    if (summary == null) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось открыть тренировку');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutDetailPage(workout: summary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Тренировки',
          style: GoogleFonts.lexendDeca(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: HomeColors.title,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadWorkouts(reset: true),
        color: HomeColors.primaryGreen,
        child: _loading && _workouts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _workouts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error.toString(),
                          textAlign: TextAlign.center,
                          style: homeSubtitleStyle(),
                        ),
                      ),
                    ],
                  )
                : _workouts.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Пока нет публичных тренировок участников клуба.',
                              textAlign: TextAlign.center,
                              style: homeSubtitleStyle(),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _workouts.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 18),
                        itemBuilder: (context, index) {
                          if (index >= _workouts.length) {
                            if (!_loadingMore) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _loadWorkouts();
                              });
                            }
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final workout = _workouts[index];
                          return ClubWorkoutCard(
                            workout: workout,
                            onTap: () => _openWorkout(workout),
                          );
                        },
                      ),
      ),
    );
  }
}
