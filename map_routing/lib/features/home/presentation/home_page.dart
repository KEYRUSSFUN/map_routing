import 'package:flutter/material.dart';
import 'package:map_routing/core/widgets/app_bottom_nav_bar.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/core/widgets/stride_track_logo.dart';
import 'package:map_routing/data/models/challenge.dart';
import 'package:map_routing/data/models/moment.dart';
import 'package:map_routing/data/models/story.dart';
import 'package:map_routing/data/services/challenge_service.dart';
import 'package:map_routing/data/services/club_service.dart';
import 'package:map_routing/data/services/moment_service.dart';
import 'package:map_routing/data/services/story_service.dart';
import 'package:map_routing/features/challenges/presentation/challenge_detail_page.dart';
import 'package:map_routing/features/clubs/presentation/club_page.dart';
import 'package:map_routing/features/home/home_page_controller.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';
import 'package:map_routing/features/moments/presentation/moment_comments_sheet.dart';
import 'package:map_routing/features/moments/presentation/moment_feed_card.dart';
import 'package:map_routing/features/stories/presentation/publish_story_dialog.dart';
import 'package:map_routing/features/stories/presentation/story_viewer_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  StoryService? _storyService;
  MomentService? _momentService;
  ChallengeService? _challengeService;
  List<StoryFeedUser> _storyUsers = [];
  List<MomentItem> _feedMoments = [];
  List<ChallengeSummary> _activeChallenges = [];
  bool _loadingStories = false;
  bool _loadingMoments = false;
  bool _loadingChallenges = false;

  static const _storiesRowHeight = 112.0;

  @override
  void initState() {
    super.initState();
    HomePageController.instance.bind(refreshData);
    HomePageController.instance.bindPresence(_updateUserPresence);
    _loadData();
  }

  void _updateUserPresence(String userId, bool isOnline) {
    if (!mounted) return;
    final parsedUserId = int.tryParse(userId);
    if (parsedUserId == null) return;

    final index = _storyUsers.indexWhere((user) => user.userId == parsedUserId);
    if (index < 0) return;

    final current = _storyUsers[index];
    if (current.isOnline == isOnline) return;

    setState(() {
      final updated = List<StoryFeedUser>.from(_storyUsers);
      updated[index] = StoryFeedUser(
        userId: current.userId,
        name: current.name,
        avatarUrl: current.avatarUrl,
        hasStory: current.hasStory,
        hasUnviewed: current.hasUnviewed,
        isMe: current.isMe,
        storyCount: current.storyCount,
        isOnline: isOnline,
      );
      _storyUsers = updated;
    });
  }

  Future<void> refreshData({bool force = false}) => _loadData(force: force);

  Future<void> _ensureServices() async {
    if (_storyService != null &&
        _momentService != null &&
        _challengeService != null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return;
    _storyService ??= StoryService(token: token);
    _momentService ??= MomentService(token: token);
    _challengeService ??= ChallengeService(token: token);
  }

  Future<void> _loadData({bool force = false}) async {
    await Future.wait([
      _loadStories(force: force),
      _loadMomentsFeed(force: force),
      _loadChallenges(force: force),
    ]);
  }

  Future<void> _loadChallenges({bool force = false}) async {
    if (_loadingChallenges) return;
    await _ensureServices();
    if (_challengeService == null) return;
    if (!force && _activeChallenges.isNotEmpty) return;

    setState(() => _loadingChallenges = true);
    try {
      final all = await _challengeService!.fetchChallenges();
      if (!mounted) return;
      setState(() {
        _activeChallenges = all
            .where((challenge) => challenge.isJoined && challenge.isActive)
            .toList();
        _loadingChallenges = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingChallenges = false);
    }
  }

  Future<void> _openChallenge(ChallengeSummary challenge) async {
    await _ensureServices();
    if (_challengeService == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChallengeDetailPage(
          challengeId: challenge.id,
          challengeService: _challengeService!,
        ),
      ),
    );
    if (!mounted) return;
    await _loadChallenges(force: true);
  }

  Future<void> _loadStories({bool force = false}) async {
    if (_loadingStories) return;
    await _ensureServices();
    if (_storyService == null) return;
    if (!force && _storyUsers.isNotEmpty) return;

    setState(() => _loadingStories = true);
    try {
      final users = await _storyService!.fetchFeed();
      if (!mounted) return;
      setState(() {
        _storyUsers = users;
        _loadingStories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStories = false);
    }
  }

  Future<void> _loadMomentsFeed({bool force = false}) async {
    if (_loadingMoments) return;
    await _ensureServices();
    if (_momentService == null) return;
    if (!force && _feedMoments.isNotEmpty) return;

    setState(() => _loadingMoments = true);
    try {
      final page = await _momentService!.fetchFeed();
      if (!mounted) return;
      setState(() {
        _feedMoments = page.moments;
        _loadingMoments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMoments = false);
    }
  }

  Future<void> _openPublishDialog() async {
    await _ensureServices();
    if (_storyService == null || !mounted) return;

    final published = await showPublishStoryDialog(
      context,
      storyService: _storyService!,
    );
    if (published == true) {
      await _loadStories(force: true);
    }
  }

  Future<void> _openUserStories(StoryFeedUser user) async {
    await _ensureServices();
    if (_storyService == null || !mounted) return;

    if (!user.hasStory) {
      if (user.isMe) {
        await _openPublishDialog();
      }
      return;
    }

    try {
      final bundle = await _storyService!.fetchUserStories(user.userId);
      if (!mounted || bundle.stories.isEmpty) return;

      final changed = await openStoryViewer(
        context,
        storyService: _storyService!,
        bundle: bundle,
        canDelete: user.isMe,
      );
      if (changed == true) {
        if (mounted) {
          setState(() {
            final index =
                _storyUsers.indexWhere((u) => u.userId == user.userId);
            if (index >= 0) {
              final current = _storyUsers[index];
              final updated = List<StoryFeedUser>.from(_storyUsers);
              updated[index] = StoryFeedUser(
                userId: current.userId,
                name: current.name,
                avatarUrl: current.avatarUrl,
                hasStory: current.hasStory,
                hasUnviewed: false,
                isMe: current.isMe,
                storyCount: current.storyCount,
                isOnline: current.isOnline,
              );
              _storyUsers = updated;
            }
          });
        }
        await _loadStories(force: true);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось открыть истории: $e');
    }
  }

  Future<void> _toggleLike(int index) async {
    if (_momentService == null) return;
    final moment = _feedMoments[index];

    try {
      final result = await _momentService!.toggleLike(moment.id);
      if (!mounted) return;
      setState(() {
        _feedMoments[index] = moment.copyWith(
          likedByMe: result.liked,
          likesCount: result.likesCount,
        );
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось поставить лайк');
    }
  }

  Future<void> _openClubPost(int clubId) async {
    final service = await ClubService.fromPrefs();
    if (!mounted || service == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubPage(
          clubService: service,
          clubId: clubId,
        ),
      ),
    );
  }

  Future<void> _openComments(int index) async {
    if (_momentService == null) return;
    final moment = _feedMoments[index];

    final newCount = await showMomentCommentsSheet(
      context,
      momentService: _momentService!,
      moment: moment,
    );

    if (!mounted || newCount == null) return;
    setState(() {
      _feedMoments[index] = moment.copyWith(commentsCount: newCount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = AppBottomNavBar.scrollEndPadding(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _loadData(force: true),
          color: HomeColors.primaryGreen,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: const StrideTrackLogo(size: 32),
                ),
                HomeSectionPanel(
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  showBottomDivider: true,
                  child: _buildStoriesRow(),
                ),
                HomeSectionPanel(
                  backgroundColor: HomeColors.challengesSectionBg,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  showBottomDivider: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HomeSectionHeader(
                        title: 'Активные челенджи',
                        trailingLabel: 'Все',
                        onTrailingTap:
                            HomePageController.instance.openProfileChallenges,
                      ),
                      const SizedBox(height: 14),
                      _buildChallengesRow(),
                    ],
                  ),
                ),

                _buildMomentsFeed(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMomentsFeed() {
    if (_loadingMoments && _feedMoments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_feedMoments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Text(
          'Лента пуста. Опубликуйте момент в профиле или запись в клубе — они появятся здесь.',
          textAlign: TextAlign.center,
          style: homeSubtitleStyle(),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _feedMoments.length; i++)
          MomentFeedCard(
            moment: _feedMoments[i],
            edgeToEdge: true,
            onLikeTap: () => _toggleLike(i),
            onCommentTap: () => _openComments(i),
            onClubTap: _feedMoments[i].clubId == null
                ? null
                : () => _openClubPost(_feedMoments[i].clubId!),
          ),
      ],
    );
  }

  Widget _buildChallengesRow() {
    if (_loadingChallenges && _activeChallenges.isEmpty) {
      return const SizedBox(
        height: 168,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeChallenges.isEmpty) {
      return SizedBox(
        height: 168,
        child: Center(
          child: Text(
            'Нет активных челленджей.\nПрисоединяйтесь во вкладке «Сообщество».',
            textAlign: TextAlign.center,
            style: homeSubtitleStyle(),
          ),
        ),
      );
    }

    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _activeChallenges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final challenge = _activeChallenges[index];
          return HomeChallengeCard(
            title: challenge.title,
            participantsLabel: challenge.participantsLabel,
            daysLeftLabel: challenge.daysLeftLabel,
            progress: challenge.progressPercent,
            onTap: () => _openChallenge(challenge),
          );
        },
      ),
    );
  }

  Widget _buildStoriesRow() {
    if (_loadingStories && _storyUsers.isEmpty) {
      return SizedBox(
        height: _storiesRowHeight,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final storyUsers = _storyUsers
        .where((user) => user.isMe || user.hasStory)
        .toList(growable: false);

    if (storyUsers.isEmpty) {
      return SizedBox(
        height: _storiesRowHeight,
        child: Center(
          child: HomeStoryAvatar(
            label: 'Вы',
            initial: 'Я',
            color: HomeColors.primaryGreen,
            showAddBadge: true,
            onTap: _openPublishDialog,
            onAddTap: _openPublishDialog,
          ),
        ),
      );
    }

    return SizedBox(
      height: _storiesRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: storyUsers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final user = storyUsers[index];
          final friendIndex =
              storyUsers.take(index).where((u) => !u.isMe).length;
          return Center(
            child: HomeStoryAvatar(
              label: user.isMe ? 'Вы' : user.name,
              initial: HomeStoryAvatar.initialFromName(user.name),
              color: user.isMe
                  ? HomeColors.primaryGreen
                  : HomeStoryAvatar.colorForFriend(friendIndex),
              avatarUrl: user.avatarUrl,
              hasStoryRing: user.hasUnviewed,
              showAddBadge: user.isMe,
              isOnline: user.isOnline,
              onTap: () => _openUserStories(user),
              onAddTap: _openPublishDialog,
            ),
          );
        },
      ),
    );
  }
}
