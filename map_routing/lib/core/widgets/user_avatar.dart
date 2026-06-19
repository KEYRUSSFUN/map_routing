import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 20,
    this.showNetworkImage = true,
    this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final double radius;
  final bool showNetworkImage;
  final VoidCallback? onTap;

  String? get _resolvedUrl {
    final value = avatarUrl?.trim();
    if (value == null || value.isEmpty || value == 'null') return null;
    final resolved = absoluteBackendUrl(value);
    if (!isLoadableNetworkUrl(resolved)) return null;
    return resolved;
  }

  Widget _letterAvatarContent() {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return ColoredBox(
      color: AuthColors.primaryGreen.withValues(alpha: 0.18),
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.lexendDeca(
            fontWeight: FontWeight.w700,
            color: AuthColors.title,
            fontSize: radius * 0.85,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final url = _resolvedUrl;
    final size = radius * 2;

    if (url == null || !showNetworkImage) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(child: _letterAvatarContent()),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _letterAvatarContent(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return ColoredBox(
              color: AuthColors.primaryGreen.withValues(alpha: 0.18),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _buildAvatar();
    if (onTap == null) return avatar;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: CircleBorder(),
        child: avatar,
      ),
    );
  }
}
