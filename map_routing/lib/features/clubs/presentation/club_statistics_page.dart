import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/navigation/open_user_profile.dart';
import 'package:map_routing/core/widgets/user_avatar.dart';
import 'package:map_routing/data/models/club.dart';
import 'package:map_routing/data/services/club_service.dart';
import 'package:map_routing/features/clubs/presentation/club_ui.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';

class ClubStatisticsPage extends StatefulWidget {
  const ClubStatisticsPage({
    super.key,
    required this.clubService,
    required this.club,
  });

  final ClubService clubService;
  final ClubSummary club;

  @override
  State<ClubStatisticsPage> createState() => _ClubStatisticsPageState();
}

class _ClubStatisticsPageState extends State<ClubStatisticsPage> {
  ClubWeeklyStats? _stats;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await widget.clubService.fetchWeeklyStats(widget.club.id);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  String _formatKm(double value) {
    final text = value.toStringAsFixed(1).replaceAll('.', ',');
    return '$text км';
  }

  String _formatM(double value) {
    final text = value.toStringAsFixed(1).replaceAll('.', ',');
    return '$text м';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Статистика за неделю',
          style: GoogleFonts.lexendDeca(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error.toString(), style: homeSubtitleStyle()))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: HomeColors.primaryGreen,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Text(
                        formatClubCount(_stats!.totalDistanceKm.round()),
                        style: GoogleFonts.lexendDeca(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: HomeColors.title,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Всего километров (клуб):',
                        style: homeSubtitleStyle(),
                      ),
                      const SizedBox(height: 20),
                      _StatLine(
                        label: 'Тренировки',
                        value: formatClubCount(_stats!.workoutsCount),
                      ),
                      _StatLine(
                        label: 'Лидер по дистанции',
                        value: _formatKm(_stats!.topDistanceKm),
                      ),
                      _StatLine(
                        label: 'Лидер по набору высоты',
                        value: _formatM(_stats!.topElevationM),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Ваши тренировки',
                        style: GoogleFonts.lexendDeca(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.title,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _StatLine(
                        label: 'Расстояние',
                        value: _formatKm(_stats!.myDistanceKm),
                      ),
                      _StatLine(
                        label: 'Набор высоты',
                        value: _formatM(_stats!.myElevationM),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'ИМЯ',
                                style: GoogleFonts.lexendDeca(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: HomeColors.body,
                                ),
                              ),
                            ),
                            Text(
                              'ДИСТАНЦИЯ',
                              style: GoogleFonts.lexendDeca(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: HomeColors.body,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...List.generate(_stats!.leaderboard.length, (index) {
                        final entry = _stats!.leaderboard[index];
                        return InkWell(
                          onTap: () => openUserProfile(context, entry.userId),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${index + 1}',
                                    style: homeSubtitleStyle(),
                                  ),
                                ),
                                UserAvatar(
                                  avatarUrl: entry.avatarUrl,
                                  name: entry.name,
                                  radius: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.name,
                                    style: GoogleFonts.lexendDeca(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: HomeColors.title,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatKm(entry.distanceKm),
                                  style: GoogleFonts.lexendDeca(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: HomeColors.title,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: homeSubtitleStyle())),
          Text(
            value,
            style: GoogleFonts.lexendDeca(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: HomeColors.title,
            ),
          ),
        ],
      ),
    );
  }
}
