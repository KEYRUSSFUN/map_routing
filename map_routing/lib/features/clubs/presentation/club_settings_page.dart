import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/models/club.dart';
import 'package:map_routing/data/services/club_service.dart';
import 'package:map_routing/features/clubs/presentation/club_ui.dart';
import 'package:map_routing/features/clubs/presentation/edit_club_page.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';

class ClubSettingsPage extends StatefulWidget {
  const ClubSettingsPage({
    super.key,
    required this.clubService,
    required this.club,
  });

  final ClubService clubService;
  final ClubSummary club;

  @override
  State<ClubSettingsPage> createState() => _ClubSettingsPageState();
}

class _ClubSettingsPageState extends State<ClubSettingsPage> {
  late bool _showActivityFeed;
  late bool _showLeaderboards;
  late bool _adminsOnlyPosting;
  late bool _isPrivate;
  late String _notificationLevel;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final club = widget.club;
    _showActivityFeed = club.showActivityFeed;
    _showLeaderboards = club.showLeaderboards;
    _adminsOnlyPosting = club.adminsOnlyPosting;
    _isPrivate = club.privacy == 'closed';
    _notificationLevel = club.notificationLevel ?? 'all';
  }

  Future<void> _save({
    bool? showActivityFeed,
    bool? showLeaderboards,
    bool? adminsOnlyPosting,
    bool? isPrivate,
    String? notificationLevel,
  }) async {
    if (_saving) return;

    setState(() {
      if (showActivityFeed != null) _showActivityFeed = showActivityFeed;
      if (showLeaderboards != null) _showLeaderboards = showLeaderboards;
      if (adminsOnlyPosting != null) _adminsOnlyPosting = adminsOnlyPosting;
      if (isPrivate != null) _isPrivate = isPrivate;
      if (notificationLevel != null) _notificationLevel = notificationLevel;
      _saving = true;
    });

    try {
      final updated = await widget.clubService.updateSettings(
        clubId: widget.club.id,
        payload: ClubSettingsPayload(
          showActivityFeed: _showActivityFeed,
          showLeaderboards: _showLeaderboards,
          adminsOnlyPosting: _adminsOnlyPosting,
          privacy: _isPrivate ? 'closed' : 'open',
          notificationLevel: widget.club.isMember ? _notificationLevel : null,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.show(context, error.toString());
      setState(() => _saving = false);
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<ClubSummary>(
      MaterialPageRoute(
        builder: (_) => EditClubPage(
          clubService: widget.clubService,
          club: widget.club,
        ),
      ),
    );
    if (updated != null && mounted) {
      Navigator.pop(context, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Настройки клуба',
          style: GoogleFonts.lexendDeca(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (widget.club.isAdmin)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Редактировать профиль клуба'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _openEdit,
            ),
          const Divider(),
          Text('Настройки показа', style: clubSectionTitleStyle()),
          ClubSettingsTile(
            title: 'Показывать ленту активности',
            trailing: Switch.adaptive(
              value: _showActivityFeed,
              activeColor: HomeColors.primaryGreen,
              onChanged: _saving ? null : (value) => _save(showActivityFeed: value),
            ),
          ),
          ClubSettingsTile(
            title: 'Показывать турнирные таблицы и статистику за неделю',
            subtitle:
                'Включите клубные лидерборды и отслеживание статистики.',
            trailing: Switch.adaptive(
              value: _showLeaderboards,
              activeColor: HomeColors.primaryGreen,
              onChanged: _saving ? null : (value) => _save(showLeaderboards: value),
            ),
          ),
          const Divider(height: 32),
          Text('Разрешения', style: clubSectionTitleStyle()),
          ClubSettingsTile(
            title: 'Закрытый клуб',
            subtitle: 'Для вступления новым участникам нужно разрешение.',
            trailing: Switch.adaptive(
              value: _isPrivate,
              activeColor: HomeColors.primaryGreen,
              onChanged: _saving ? null : (value) => _save(isPrivate: value),
            ),
          ),
          ClubSettingsTile(
            title: 'Публиковать записи могут только администраторы',
            subtitle: 'Участники клуба не смогут публиковать записи.',
            trailing: Switch.adaptive(
              value: _adminsOnlyPosting,
              activeColor: HomeColors.primaryGreen,
              onChanged: _saving ? null : (value) => _save(adminsOnlyPosting: value),
            ),
          ),
          if (widget.club.isMember) ...[
            const Divider(height: 32),
            Text('Уведомления', style: clubSectionTitleStyle()),
            _NotificationTile(
              title: 'Все записи',
              subtitle: 'Получать уведомления обо всех записях в клубе.',
              value: 'all',
              groupValue: _notificationLevel,
              onChanged: (value) => _save(notificationLevel: value),
            ),
            _NotificationTile(
              title: 'Объявления',
              subtitle: 'Только записи администраторов клуба.',
              value: 'announcements',
              groupValue: _notificationLevel,
              onChanged: (value) => _save(notificationLevel: value),
            ),
            _NotificationTile(
              title: 'Выкл.',
              subtitle: 'Не получать уведомления о записях.',
              value: 'off',
              groupValue: _notificationLevel,
              onChanged: (value) => _save(notificationLevel: value),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.lexendDeca(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.title,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: homeSubtitleStyle()),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              activeColor: HomeColors.primaryGreen,
              onChanged: (_) => onChanged(value),
            ),
          ],
        ),
      ),
    );
  }
}
