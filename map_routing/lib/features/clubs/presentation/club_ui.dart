import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/data/models/club.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/clubs/presentation/club_wizard_options.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';

String formatClubCount(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final pos = text.length - i;
    buffer.write(text[i]);
    if (pos > 1 && pos % 3 == 1) buffer.write(' ');
  }
  return buffer.toString();
}

String clubPrivacyLabel(String privacy) =>
    privacy == 'closed' ? 'Закрытый' : 'Открытый';

String clubMembersLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod100 >= 11 && mod100 <= 14) return 'участников';
  if (mod10 == 1) return 'участник';
  if (mod10 >= 2 && mod10 <= 4) return 'участника';
  return 'участников';
}

TextStyle clubSectionTitleStyle() => GoogleFonts.lexendDeca(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: HomeColors.body,
    );

TextStyle clubPageTitleStyle() => GoogleFonts.lexendDeca(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      color: HomeColors.title,
      height: 1.1,
    );

class ClubCoverHeader extends StatelessWidget {
  const ClubCoverHeader({
    super.key,
    required this.club,
    this.onBack,
    this.actions = const [],
    this.avatarSize = 72,
    this.coverHeight = 168,
  });

  final ClubSummary club;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final double avatarSize;
  final double coverHeight;

  @override
  Widget build(BuildContext context) {
    final coverUrl = absoluteBackendUrl(club.coverUrl);
    final avatarUrl = absoluteBackendUrl(club.avatarUrl);
    final topInset = MediaQuery.paddingOf(context).top + 8;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: coverHeight,
          width: double.infinity,
          child: isLoadableNetworkUrl(coverUrl)
              ? Image.network(
                  coverUrl!,
                  key: ValueKey(coverUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _CoverFallback(),
                )
              : const _CoverFallback(),
        ),
        Positioned(
          top: topInset,
          left: 8,
          right: 8,
          child: Row(
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack ?? () => Navigator.maybePop(context),
              ),
              const Spacer(),
              ...actions,
            ],
          ),
        ),
        Positioned(
          left: 16,
          bottom: -(avatarSize / 2),
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: isLoadableNetworkUrl(avatarUrl)
                  ? Image.network(
                      avatarUrl!,
                      key: ValueKey(avatarUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ClubAvatarFallback(title: club.title),
                    )
                  : ClubAvatarFallback(title: club.title),
            ),
          ),
        ),
      ],
    );
  }
}

class ClubAvatarFallback extends StatelessWidget {
  const ClubAvatarFallback({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final letter = title.trim().isNotEmpty ? title.trim()[0].toUpperCase() : '?';
    return ColoredBox(
      color: HomeColors.primaryGreen.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.lexendDeca(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: HomeColors.primaryGreen,
          ),
        ),
      ),
    );
  }
}

class ClubMetaRow extends StatelessWidget {
  const ClubMetaRow({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: HomeColors.body),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: homeSubtitleStyle(),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class ClubQuickAction extends StatelessWidget {
  const ClubQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: selected
                      ? HomeColors.primaryGreen.withValues(alpha: 0.12)
                      : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? HomeColors.primaryGreen : HomeColors.title,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.lexendDeca(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HomeColors.title,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClubOutlinedField extends StatelessWidget {
  const ClubOutlinedField({
    super.key,
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      style: authFieldStyle(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: authLabelStyle(),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AuthColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AuthColors.primaryGreen, width: 1.4),
        ),
      ),
    );
  }
}

class ClubSettingsTile extends StatelessWidget {
  const ClubSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: homeSubtitleStyle(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class ClubInfoBlock extends StatelessWidget {
  const ClubInfoBlock({super.key, required this.club});

  final ClubSummary club;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 44, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(club.title, style: clubPageTitleStyle()),
          const SizedBox(height: 10),
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
              if (club.locationLabel?.isNotEmpty ?? false)
                ClubMetaRow(
                  icon: Icons.place_outlined,
                  label: club.locationLabel!,
                ),
            ],
          ),
          if (club.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              club.description,
              style: GoogleFonts.lexendDeca(
                fontSize: 14,
                height: 1.45,
                color: HomeColors.title,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.groups_rounded,
          size: 56,
          color: Colors.white.withValues(alpha: 0.35),
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
    return Material(
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
    );
  }
}
