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

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: StrideTrackLogo.primaryGreen,
      body: Center(
        child: Image(
          image: AssetImage(StrideTrackLogo.assetPath),
          width: 128,
          height: 128,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
