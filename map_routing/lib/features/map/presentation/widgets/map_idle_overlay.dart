import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';

class MapIdleOverlay extends StatelessWidget {
  const MapIdleOverlay({
    super.key,
    required this.selectedActivity,
    required this.onActivitySelected,
    required this.onStartWorkout,
    required this.onCenterLocation,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onClearRoutes,
    required this.onSwitchRoutingType,
    required this.onSaveRoute,
    required this.bottomPadding,
  });

  final WorkoutActivityType selectedActivity;
  final ValueChanged<WorkoutActivityType> onActivitySelected;
  final VoidCallback onStartWorkout;
  final VoidCallback onCenterLocation;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onClearRoutes;
  final VoidCallback onSwitchRoutingType;
  final VoidCallback onSaveRoute;
  final double bottomPadding;

  static const _activities = WorkoutActivityType.values;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned(
          top: top + 8,
          left: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: MapUiColors.body.withValues(alpha: 0.8)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Поиск маршрутов, троп...',
                              style: GoogleFonts.lexendDeca(
                                fontSize: 14,
                                color: MapUiColors.body,
                              ),
                            ),
                          ),
                          Icon(Icons.tune_rounded,
                              color: MapUiColors.primaryGreen, size: 22),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _activities.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final type = _activities[index];
                    final selected = type == selectedActivity;
                    return GestureDetector(
                      onTap: () => onActivitySelected(type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? MapUiColors.primaryGreen.withValues(alpha: 0.60)
                              : Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? MapUiColors.primaryGreen
                                : const Color(0xFFE8E8E8),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(type.icon,
                                size: 18,
                                color: const Color.fromARGB(255, 0, 0, 0)),
                            const SizedBox(width: 6),
                            Text(type.labelRu, style: mapChipLabelStyle()),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: bottomPadding + 140,
          child: Column(
            children: [
              _CircleTool(icon: Icons.add, onTap: onZoomIn),
              const SizedBox(height: 8),
              _CircleTool(icon: Icons.remove, onTap: onZoomOut),
            ],
          ),
        ),
        Positioned(
          left: 16,
          bottom: bottomPadding + 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CircleTool(icon: Icons.delete_outline, onTap: onClearRoutes),
              const SizedBox(height: 8),
              _CircleTool(icon: Icons.swap_horiz, onTap: onSwitchRoutingType),
              const SizedBox(height: 8),
              _CircleTool(icon: Icons.save_alt_outlined, onTap: onSaveRoute),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomPadding + 0,
          child: Center(
            child: _CircleTool(
              icon: Icons.my_location_rounded,
              onTap: onCenterLocation,
              iconColor: MapUiColors.primaryGreen,
              size: 52,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleTool extends StatelessWidget {
  const _CircleTool({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon,
              color: iconColor ?? const Color.fromARGB(255, 0, 0, 0), size: 22),
        ),
      ),
    );
  }
}
