import 'package:flutter/material.dart';
import 'package:map_routing/core/widgets/app_confirm_dialog.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/models/club.dart';
import 'package:map_routing/data/models/moment.dart';
import 'package:map_routing/data/services/club_service.dart';
import 'package:map_routing/data/services/moment_service.dart';
import 'package:map_routing/features/chat/presentation/chat_screen_page.dart';
import 'package:map_routing/features/clubs/presentation/club_overview_page.dart';
import 'package:map_routing/features/clubs/presentation/club_settings_page.dart';
import 'package:map_routing/features/clubs/presentation/club_statistics_page.dart';
import 'package:map_routing/features/clubs/presentation/club_ui.dart';
import 'package:map_routing/features/clubs/presentation/club_workouts_page.dart';
import 'package:map_routing/features/clubs/presentation/publish_club_post_sheet.dart';
import 'package:map_routing/features/home/home_page_controller.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';
import 'package:map_routing/features/moments/presentation/edit_moment_sheet.dart';
import 'package:map_routing/features/moments/presentation/moment_comments_sheet.dart';
import 'package:map_routing/features/moments/presentation/moment_feed_card.dart';

class ClubPage extends StatefulWidget {
  const ClubPage({
    super.key,
    required this.clubService,
    required this.clubId,
    this.initialClub,
  });

  final ClubService clubService;
  final int clubId;
  final ClubSummary? initialClub;

  @override
  State<ClubPage> createState() => _ClubPageState();
}

class _ClubPageState extends State<ClubPage> {
  ClubSummary? _club;
  MomentService? _momentService;
  List<MomentItem> _posts = [];
  bool _loadingClub = false;
  bool _loadingPosts = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _club = widget.initialClub;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final service = await MomentService.fromPrefs();
    if (!mounted) return;
    setState(() => _momentService = service);
    await Future.wait([_loadClub(), _loadPosts(reset: true)]);
  }

  Future<void> _loadClub() async {
    setState(() {
      _loadingClub = _club == null;
      _error = null;
    });
    try {
      final club = await widget.clubService.fetchClub(widget.clubId);
      if (!mounted) return;
      setState(() {
        _club = club;
        _loadingClub = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loadingClub = false;
      });
    }
  }

  Future<void> _loadPosts({bool reset = false}) async {
    if (_loadingPosts || _loadingMore) return;
    final nextPage = reset ? 1 : _page + 1;

    setState(() {
      if (reset) {
        _loadingPosts = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await widget.clubService.fetchPosts(
        clubId: widget.clubId,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _posts = result.posts;
        } else {
          _posts = [..._posts, ...result.posts];
        }
        _page = result.page;
        _hasMore = result.hasMore;
        _loadingPosts = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPosts = false;
        _loadingMore = false;
      });
      if (reset) {
        AppSnackBar.show(context, 'Не удалось загрузить записи клуба');
      }
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadClub(), _loadPosts(reset: true)]);
  }

  Future<void> _openSettings() async {
    final club = _club;
    if (club == null || !club.isAdmin) return;

    final updated = await Navigator.of(context).push<ClubSummary>(
      MaterialPageRoute(
        builder: (_) => ClubSettingsPage(
          clubService: widget.clubService,
          club: club,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _club = updated);
      await _loadClub();
    }
  }

  Future<void> _openOverview() async {
    final club = _club;
    if (club == null) return;

    final updated = await Navigator.of(context).push<ClubSummary>(
      MaterialPageRoute(
        builder: (_) => ClubOverviewPage(
          clubService: widget.clubService,
          club: club,
        ),
      ),
    );

    if (!mounted) return;
    if (updated != null) {
      setState(() => _club = updated);
      await _loadPosts(reset: true);
    }
  }

  Future<void> _openStatistics() async {
    final club = _club;
    if (club == null || !club.showLeaderboards) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubStatisticsPage(
          clubService: widget.clubService,
          club: club,
        ),
      ),
    );
  }

  Future<void> _openChat() async {
    final chatId = _club?.groupChatId?.toString();
    if (chatId == null || chatId.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          initialTitle: _club?.title,
        ),
      ),
    );
  }

  Future<void> _openWorkouts() async {
    final club = _club;
    if (club == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubWorkoutsPage(
          clubService: widget.clubService,
          club: club,
        ),
      ),
    );
  }

  Future<void> _openPublishSheet() async {
    final club = _club;
    if (club == null || !club.canPost) return;

    final published = await showPublishClubPostSheet(
      context,
      clubService: widget.clubService,
      clubId: club.id,
    );

    if (published == true) {
      await _loadPosts(reset: true);
    }
  }

  Future<void> _toggleLike(int index) async {
    final service = _momentService;
    if (service == null) return;

    final moment = _posts[index];

    try {
      final result = await service.toggleLike(moment.id);
      if (!mounted) return;
      setState(() {
        _posts[index] = moment.copyWith(
          likedByMe: result.liked,
          likesCount: result.likesCount,
        );
      });
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось обновить реакцию');
    }
  }

  Future<void> _editPost(int index) async {
    final service = _momentService;
    if (service == null) return;

    final moment = _posts[index];
    final updated = await showEditMomentSheet(
      context,
      momentService: service,
      moment: moment,
    );

    if (!mounted || updated == null) return;
    setState(() => _posts[index] = updated);
    await HomePageController.instance.refresh(force: true);
  }

  Future<void> _deletePost(int index) async {
    final service = _momentService;
    if (service == null) return;
    final moment = _posts[index];

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Удалить запись?',
      message: 'Запись будет удалена из клуба и общей ленты.',
      confirmLabel: 'Удалить',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (!confirmed || !mounted) return;

    try {
      await service.deleteMoment(moment.id);
      if (!mounted) return;
      setState(() => _posts.removeAt(index));
      await HomePageController.instance.refresh(force: true);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось удалить запись');
    }
  }

  Future<void> _openComments(int index) async {
    final service = _momentService;
    if (service == null) return;

    final moment = _posts[index];
    final newCount = await showMomentCommentsSheet(
      context,
      momentService: service,
      moment: moment,
    );

    if (!mounted || newCount == null) return;
    setState(() {
      _posts[index] = moment.copyWith(commentsCount: newCount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final club = _club;

    if (_loadingClub && club == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (club == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            _error?.toString() ?? 'Клуб не найден',
            textAlign: TextAlign.center,
            style: homeSubtitleStyle(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: HomeColors.primaryGreen,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClubCoverHeader(
                    club: club,
                    actions: [
                      if (club.isAdmin)
                        _CircleIconButton(
                          icon: Icons.settings_outlined,
                          onTap: _openSettings,
                        ),
                    ],
                  ),
                  ClubInfoBlock(club: club),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        if (club.showLeaderboards)
                          ClubQuickAction(
                            icon: Icons.bar_chart_rounded,
                            label: 'Статистика',
                            onTap: _openStatistics,
                          ),
                        ClubQuickAction(
                          icon: Icons.info_outline_rounded,
                          label: 'Обзор',
                          onTap: _openOverview,
                        ),
                        if (club.groupChatId != null && club.isMember)
                          ClubQuickAction(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Чат',
                            onTap: _openChat,
                          ),
                        ClubQuickAction(
                          icon: Icons.directions_run_rounded,
                          label: 'Тренировки',
                          onTap: _openWorkouts,
                        ),
                      ],
                    ),
                  ),
                  if (club.showActivityFeed && club.canPost) ...[
                    const SizedBox(height: 8),
                    _PostComposer(onTap: _openPublishSheet),
                  ] else if (!club.isMember && club.isOpen) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FilledButton(
                        onPressed: _openOverview,
                        style: FilledButton.styleFrom(
                          backgroundColor: HomeColors.primaryGreen,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Вступить в клуб'),
                      ),
                    ),
                  ] else if (club.membershipPending) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Заявка на вступление отправлена и ожидает одобрения.',
                        textAlign: TextAlign.center,
                        style: homeSubtitleStyle(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
            if (!club.showActivityFeed)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Лента активности клуба отключена администратором.',
                      textAlign: TextAlign.center,
                      style: homeSubtitleStyle(),
                    ),
                  ),
                ),
              )
            else if (_loadingPosts && _posts.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      club.canPost
                          ? 'Пока нет записей. Будьте первым — поделитесь новостью!'
                          : 'В клубе пока нет записей.',
                      textAlign: TextAlign.center,
                      style: homeSubtitleStyle(),
                    ),
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: _posts.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index >= _posts.length) {
                    if (!_loadingMore) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _loadPosts();
                      });
                    }
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return MomentFeedCard(
                    moment: _posts[index],
                    edgeToEdge: true,
                    showClubContext: false,
                    onLikeTap: () => _toggleLike(index),
                    onCommentTap: () => _openComments(index),
                    onEditTap: _posts[index].isMe ? () => _editPost(index) : null,
                    onDeleteTap: _posts[index].isMe ? () => _deletePost(index) : null,
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _PostComposer extends StatelessWidget {
  const _PostComposer({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFECEFF1),
                child: Icon(Icons.person_outline, size: 20, color: HomeColors.body),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Поделитесь чем-нибудь...',
                    style: homeSubtitleStyle(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onTap,
                icon: const Icon(Icons.image_outlined, color: HomeColors.body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 22, color: HomeColors.title),
          ),
        ),
      ),
    );
  }
}
