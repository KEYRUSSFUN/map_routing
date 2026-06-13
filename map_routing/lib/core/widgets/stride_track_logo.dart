import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StrideTrackLogo extends StatelessWidget {
  const StrideTrackLogo({
    super.key,
    this.size = 32,
    this.showLabel = true,
    this.labelStyle,
  });

  final double size;
  final bool showLabel;
  final TextStyle? labelStyle;

  static const assetPath = 'assets/branding/logo.png';
  static const primaryGreen = Color(0xFF00E676);

  static TextStyle defaultLabelStyle() => GoogleFonts.lexendDeca(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: primaryGreen,
        letterSpacing: -0.4,
      );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        if (showLabel) ...[
          SizedBox(width: size * 0.25),
          Text(
            'StrideTrack',
            style: labelStyle ?? defaultLabelStyle(),
          ),
        ],
      ],
    );
  }
}

class StrideTrackSplash extends StatelessWidget {
  const StrideTrackSplash({super.key});

  static const _maxLogoSize = 128.0;

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final logoSize = (shortestSide * 0.25).clamp(96.0, _maxLogoSize);

    return Scaffold(
      backgroundColor: StrideTrackLogo.primaryGreen,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Image.asset(
              StrideTrackLogo.assetPath,
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
