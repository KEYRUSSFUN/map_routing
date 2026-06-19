import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onStartWorkout,
    this.showWorkoutBanner = false,
    this.onReturnToWorkout,
  });

  static const primaryGreen = Color(0xFF00E676);
  static const inactiveColor = Color(0xFF757575);

  static const double barSlotHeight = 88;
  static const double contentGap = 4;

  static double scrollEndPadding(BuildContext context) {
    return barSlotHeight + contentGap + MediaQuery.paddingOf(context).bottom;
  }

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onStartWorkout;
  final bool showWorkoutBanner;
  final VoidCallback? onReturnToWorkout;

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showWorkoutBanner)
          Material(
            color: primaryGreen,
            child: InkWell(
              onTap: onReturnToWorkout,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.personRunning,
                        size: 16, color: Color(0xFF030303)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Тренировка идёт — нажмите, чтобы вернуться',
                        style: GoogleFonts.lexendDeca(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF030303),
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF030303)),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(
          height: barSlotHeight + bottomSafe,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: 20,
                right: 20,
                bottom: bottomSafe + 8,
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(color: const Color(0xFFF0F0F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _NavItem(
                        label: 'Главная',
                        icon: FontAwesomeIcons.house,
                        activeIcon: FontAwesomeIcons.house,
                        isSelected: selectedIndex == 0,
                        onTap: () => onItemSelected(0),
                      ),
                      _NavItem(
                        label: 'Карта',
                        icon: FontAwesomeIcons.mapLocationDot,
                        activeIcon: FontAwesomeIcons.mapLocationDot,
                        isSelected: selectedIndex == 1,
                        onTap: () => onItemSelected(1),
                      ),
                      const Expanded(child: SizedBox(width: 56)),
                      _NavItem(
                        label: 'Группы',
                        icon: FontAwesomeIcons.userGroup,
                        activeIcon: FontAwesomeIcons.userGroup,
                        isSelected: selectedIndex == 3,
                        onTap: () => onItemSelected(3),
                      ),
                      _NavItem(
                        label: 'Профиль',
                        icon: FontAwesomeIcons.circleUser,
                        activeIcon: FontAwesomeIcons.solidCircleUser,
                        isSelected: selectedIndex == 4,
                        onTap: () => onItemSelected(4),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: bottomSafe + 20,
                child: _StartWorkoutButton(onTap: onStartWorkout),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final FaIconData icon;
  final FaIconData activeIcon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? AppBottomNavBar.primaryGreen
        : AppBottomNavBar.inactiveColor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(isSelected ? activeIcon : icon, color: color, size: 21),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lexendDeca(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartWorkoutButton extends StatelessWidget {
  const _StartWorkoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: AppBottomNavBar.primaryGreen.withValues(alpha: 0.45),
      color: AppBottomNavBar.primaryGreen,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 58,
          height: 58,
          child: Center(
            child: FaIcon(
              FontAwesomeIcons.personRunning,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
