import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/navigation/open_user_profile.dart';
import 'package:map_routing/core/widgets/app_confirm_dialog.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/core/widgets/user_avatar.dart';
import 'package:map_routing/data/models/club.dart';
import 'package:map_routing/data/services/club_service.dart';
import 'package:map_routing/features/clubs/presentation/club_ui.dart';
import 'package:map_routing/features/clubs/presentation/club_wizard_options.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';

class ClubOverviewPage extends StatefulWidget {
  const ClubOverviewPage({
    super.key,
    required this.clubService,
    required this.club,
  });

  final ClubService clubService;
  final ClubSummary club;

  @override
  State<ClubOverviewPage> createState() => _ClubOverviewPageState();
}

class _ClubOverviewPageState extends State<ClubOverviewPage> {
  List<ClubMemberItem> _members = [];
  bool _loadingMembers = false;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final members = await widget.clubService.fetchMembers(widget.club.id);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loadingMembers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMembers = false);
    }
  }

  Future<void> _join() async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await widget.clubService.joinClub(widget.club.id);
      final updated = await widget.clubService.fetchClub(widget.club.id);
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.show(context, error.toString());
      setState(() => _actionInProgress = false);
    }
  }

  Future<void> _leave() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Выйти из клуба?',
      message: 'Вы перестанете видеть записи клуба в ленте и потеряете доступ к чату.',
      confirmLabel: 'Выйти',
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      await widget.clubService.leaveClub(widget.club.id);
      if (!mounted) return;
      final updated = await widget.clubService.fetchClub(widget.club.id);
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.show(context, error.toString());
      setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Обзор',
          style: GoogleFonts.lexendDeca(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(club.title, style: clubPageTitleStyle()),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              ClubMetaRow(
                icon: Icons.directions_run_rounded,
                label: clubSportLabel(club.sportType),
              ),
              ClubMetaRow(
                icon: Icons.people_outline_rounded,
                label:
                    '${formatClubCount(club.memberCount)} ${clubMembersLabel(club.memberCount)}',
              ),
              ClubMetaRow(
                icon: club.isOpen ? Icons.public_rounded : Icons.lock_outline_rounded,
                label: clubPrivacyLabel(club.privacy),
              ),
              if (clubLocationLabel(club.locationLabel).isNotEmpty)
                ClubMetaRow(
                  icon: Icons.place_outlined,
                  label: clubLocationLabel(club.locationLabel),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('О клубе', style: clubSectionTitleStyle()),
          const SizedBox(height: 8),
          Text(
            club.description.isNotEmpty
                ? club.description
                : 'Описание клуба пока не добавлено.',
            style: GoogleFonts.lexendDeca(
              fontSize: 14,
              height: 1.45,
              color: HomeColors.title,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Участники', style: clubSectionTitleStyle()),
              const Spacer(),
              Text(
                formatClubCount(club.memberCount),
                style: homeSubtitleStyle(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingMembers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._members.map(
              (member) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    UserAvatar(
                      avatarUrl: member.avatarUrl,
                      name: member.name,
                      radius: 22,
                      onTap: member.isMe
                          ? null
                          : () => openUserProfile(context, member.userId),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: GoogleFonts.lexendDeca(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: HomeColors.title,
                            ),
                          ),
                          if (member.location != null && member.location!.isNotEmpty)
                            Text(
                              member.location!,
                              style: homeSubtitleStyle(),
                            ),
                        ],
                      ),
                    ),
                    if (member.roleLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: HomeColors.cardBorder),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          member.roleLabel,
                          style: GoogleFonts.lexendDeca(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: HomeColors.body,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('Действия', style: clubSectionTitleStyle()),
          const SizedBox(height: 12),
          if (!club.isMember && !club.membershipPending)
            FilledButton(
              onPressed: _actionInProgress ? null : _join,
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.primaryGreen,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _actionInProgress
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(club.isClosed ? 'Подать заявку' : 'Вступить в клуб'),
            )
          else if (club.membershipPending)
            OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Заявка на рассмотрении'),
            )
          else if (!club.isOwner) ...[
            FilledButton(
              onPressed: _actionInProgress ? null : _leave,
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.primaryGreen,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Выйти из клуба'),
            ),
          ],
        ],
      ),
    );
  }
}
