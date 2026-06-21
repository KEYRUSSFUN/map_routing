import 'package:flutter/material.dart';
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/features/profile/presentation/profile_cover_presets.dart';

class ProfileCoverBackground extends StatelessWidget {
  const ProfileCoverBackground({
    super.key,
    this.coverUrl,
    this.coverPresetId,
    this.height,
    this.borderRadius,
  });

  final String? coverUrl;
  final String? coverPresetId;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = absoluteBackendUrl(coverUrl);
    final preset = ProfileCoverPresets.byId(coverPresetId);

    Widget content;
    if (isLoadableNetworkUrl(resolvedUrl)) {
      content = Image.network(
        resolvedUrl!,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _PresetCover(preset: preset),
      );
    } else {
      content = _PresetCover(preset: preset);
    }

    final clipped = borderRadius == null
        ? content
        : ClipRRect(borderRadius: borderRadius!, child: content);

    if (height == null) return clipped;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: clipped,
    );
  }
}

class _PresetCover extends StatelessWidget {
  const _PresetCover({this.preset});

  final ProfileCoverPreset? preset;

  @override
  Widget build(BuildContext context) {
    final active = preset ?? ProfileCoverPresets.fallback;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: active.begin,
          end: active.end,
          colors: active.colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -18,
            bottom: -24,
            child: Icon(
              active.icon,
              size: 140,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            left: 20,
            top: 28,
            child: Icon(
              active.icon,
              size: 56,
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
        ],
      ),
    );
  }
}
