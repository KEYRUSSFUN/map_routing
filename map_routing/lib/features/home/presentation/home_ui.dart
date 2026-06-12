import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Цвета и типографика домашней ленты StrideTrack.
/// Вынесены отдельно, чтобы все секции выглядели единообразно.
abstract final class HomeColors {
  static const primaryGreen = Color(0xFF00E676);
  static const title = Color(0xFF030303);
  static const body = Color(0xFF757575);
  static const hint = Color(0xFF94A3B8);
  static const scaffoldBg = Color(0xFFF7F7F7);
  static const cardBg = Colors.white;
  static const challengeBg = Color(0xFF1A1A1A);
  static const challengeAccent = Color(0xFFFF9800);
  static const storyRing = Color(0xFF00E676);
  static const storyRingViewed = Color(0xFFE0E0E0);
  static const likeActive = Color(0xFFFF9800);
  static const mapGradientStart = Color(0xFFDCEFE2);
  static const mapGradientEnd = Color(0xFFF4F8F5);
}

TextStyle homeSectionTitleStyle() => GoogleFonts.lexendDeca(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: HomeColors.title,
    );

TextStyle homeLinkStyle() => GoogleFonts.lexendDeca(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: HomeColors.primaryGreen,
    );

TextStyle homeStoryNameStyle() => GoogleFonts.lexendDeca(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: HomeColors.title,
    );

TextStyle homeCardTitleStyle() => GoogleFonts.lexendDeca(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: HomeColors.title,
    );

TextStyle homeCardSubtitleStyle() => GoogleFonts.lexendDeca(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: HomeColors.body,
    );

TextStyle homeMetricValueStyle({Color? color}) => GoogleFonts.lexendDeca(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: color ?? HomeColors.title,
    );

TextStyle homeMetricLabelStyle() => GoogleFonts.lexendDeca(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: HomeColors.body,
    );

TextStyle homeChallengeTitleStyle() => GoogleFonts.lexendDeca(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );

TextStyle homeChallengeMetaStyle() => GoogleFonts.lexendDeca(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: Color(0xFFB0B0B0),
    );

/// Общая декорация белых карточек ленты.
BoxDecoration homeCardDecoration() => BoxDecoration(
      color: HomeColors.cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE8E8E8)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );
