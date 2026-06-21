import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/core/navigation/open_user_profile.dart';
import 'package:map_routing/core/widgets/user_avatar.dart';
import 'package:map_routing/data/models/story.dart';
import 'package:map_routing/data/services/story_service.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';

class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({
    super.key,
    required this.storyService,
    required this.userName,
    required this.avatarUrl,
    required this.stories,
    this.userId,
    this.initialIndex = 0,
    this.canDelete = false,
  });

  final StoryService storyService;
  final String userName;
  final String? avatarUrl;
  final List<StoryItem> stories;
  final int? userId;
  final int initialIndex;
  final bool canDelete;

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  late int _index;
  late List<StoryItem> _stories;
  Timer? _timer;
  double _progress = 0;
  bool _paused = false;
  bool _isClosing = false;
  static const _storyDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _stories = List<StoryItem>.from(widget.stories);
    if (_stories.isEmpty) return;
    _index = widget.initialIndex.clamp(0, _stories.length - 1);
    _markCurrentViewed();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (!mounted || _isClosing) return;
    setState(() => _progress = 0);
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_paused || !mounted || _isClosing) return;

      final nextProgress = _progress + 50 / _storyDuration.inMilliseconds;
      if (nextProgress >= 1) {
        _timer?.cancel();
        _goNext();
        return;
      }

      setState(() => _progress = nextProgress);
    });
  }

  Future<void> _markCurrentViewed() async {
    if (_stories.isEmpty || _index < 0 || _index >= _stories.length) return;
    try {
      await widget.storyService.markViewed(_stories[_index].id);
    } catch (_) {}
  }

  void _closeViewer({bool changed = true}) {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    _timer?.cancel();
    _timer = null;
    Navigator.of(context).pop(changed);
  }

  void _goNext() {
    if (!mounted || _isClosing) return;

    if (_index >= _stories.length - 1) {
      _closeViewer();
      return;
    }

    setState(() {
      _index += 1;
      _progress = 0;
    });
    _markCurrentViewed();
    _startTimer();
  }

  void _goPrevious() {
    if (!mounted || _isClosing) return;

    if (_index == 0) {
      setState(() => _progress = 0);
      _startTimer();
      return;
    }

    setState(() {
      _index -= 1;
      _progress = 0;
    });
    _markCurrentViewed();
    _startTimer();
  }

  Future<void> _deleteCurrent() async {
    final story = _stories[_index];
    try {
      await widget.storyService.deleteStory(story.id);
      if (!mounted) return;
      if (_stories.length <= 1) {
        _closeViewer();
        return;
      }
      setState(() {
        _stories.removeAt(_index);
        if (_index >= _stories.length) {
          _index = _stories.length - 1;
        }
      });
      _startTimer();
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось удалить историю');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Истории недоступны')),
      );
    }

    final story = _stories[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.sizeOf(context).width;
          if (details.localPosition.dx < width * 0.35) {
            _goPrevious();
          } else {
            _goNext();
          }
        },
        onLongPressStart: (_) {
          if (_isClosing) return;
          setState(() => _paused = true);
        },
        onLongPressEnd: (_) {
          if (_isClosing || !mounted) return;
          setState(() => _paused = false);
          _startTimer();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              story.mediaUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: List.generate(_stories.length, (i) {
                        final value = i < _index
                            ? 1.0
                            : i == _index
                                ? _progress.clamp(0.0, 1.0)
                                : 0.0;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: value,
                                minHeight: 3,
                                backgroundColor: Colors.white24,
                                color: HomeColors.primaryGreen,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
                    child: Row(
                      children: [
                        UserAvatar(
                          name: widget.userName,
                          avatarUrl: widget.avatarUrl,
                          radius: 18,
                          onTap: widget.canDelete
                              ? null
                              : () => openUserProfile(context, widget.userId),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.userName,
                            style: GoogleFonts.lexendDeca(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (widget.canDelete)
                          IconButton(
                            onPressed: _deleteCurrent,
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white),
                          ),
                        IconButton(
                          onPressed: () => _closeViewer(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (story.caption != null && story.caption!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.black45,
                      child: Text(
                        story.caption!,
                        style: GoogleFonts.lexendDeca(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> openStoryViewer(
  BuildContext context, {
  required StoryService storyService,
  required StoryUserBundle bundle,
  bool canDelete = false,
}) {
  if (bundle.stories.isEmpty) return Future.value(null);

  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => StoryViewerPage(
        storyService: storyService,
        userName: bundle.name,
        avatarUrl: bundle.avatarUrl,
        userId: bundle.userId,
        stories: List<StoryItem>.from(bundle.stories),
        canDelete: canDelete,
      ),
    ),
  );
}
