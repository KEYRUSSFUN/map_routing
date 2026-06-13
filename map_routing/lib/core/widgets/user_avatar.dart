import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 20,
    this.showNetworkImage = true,
  });

  final String name;
  final String? avatarUrl;
  final double radius;
  final bool showNetworkImage;

  String? get _resolvedUrl {
    final value = avatarUrl?.trim();
    if (value == null || value.isEmpty || value == 'null') return null;
    return value;
  }

  Widget _letterAvatar() {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: AuthColors.primaryGreen.withValues(alpha: 0.18),
      child: Text(
        letter,
        style: GoogleFonts.lexendDeca(
          fontWeight: FontWeight.w700,
          color: AuthColors.title,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl;
    final size = radius * 2;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (size * devicePixelRatio).round();

    if (url == null || !showNetworkImage) {
      return _letterAvatar();
    }

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        errorBuilder: (_, __, ___) => _letterAvatar(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: size,
            height: size,
            child: ColoredBox(
              color: AuthColors.primaryGreen.withValues(alpha: 0.18),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
