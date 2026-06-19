import 'package:flutter/material.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';
import 'package:map_routing/features/map/presentation/widgets/map_address_search_bar.dart';
import 'package:map_routing/data/services/yandex_address_suggest_service.dart';
import 'package:map_routing/data/models/address_suggestion.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' hide Icon;

class MapIdleOverlay extends StatefulWidget {
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
    required this.bottomPadding,
    required this.addressSearchService,
    required this.getSearchBounds,
    this.getUserPosition,
    required this.onAddressSelected,
    this.onStartAddressSelected,
    this.onEndAddressSelected,
  });

  final WorkoutActivityType selectedActivity;
  final ValueChanged<WorkoutActivityType> onActivitySelected;
  final VoidCallback onStartWorkout;
  final VoidCallback onCenterLocation;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onClearRoutes;
  final VoidCallback onSwitchRoutingType;
  final double bottomPadding;
  final YandexAddressSuggestService addressSearchService;
  final BoundingBox Function() getSearchBounds;
  final Point? Function()? getUserPosition;
  final ValueChanged<AddressSuggestion> onAddressSelected;
  final ValueChanged<AddressSuggestion>? onStartAddressSelected;
  final ValueChanged<AddressSuggestion>? onEndAddressSelected;

  @override
  State<MapIdleOverlay> createState() => _MapIdleOverlayState();
}

class _MapIdleOverlayState extends State<MapIdleOverlay>
    with WidgetsBindingObserver {
  static const _activities = WorkoutActivityType.values;
  static const _keyboardGap = 20.0;
  static const _sideToolsOffset = 140.0;
  static const _animDuration = Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    setState(() {});
  }

  bool _isKeyboardVisible(BuildContext context) {
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio > 0;
  }

  bool get _compactControls => _isKeyboardVisible(context);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final compact = _compactControls;
    final controlsBottom = compact ? _keyboardGap : widget.bottomPadding;
    final sideControlsBottom =
        compact ? _keyboardGap : widget.bottomPadding + _sideToolsOffset;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: top + 8,
          left: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              MapAddressSearchBar(
                searchService: widget.addressSearchService,
                getSearchBounds: widget.getSearchBounds,
                getUserPosition: widget.getUserPosition,
                onAddressSelected: widget.onAddressSelected,
                onStartAddressSelected: widget.onStartAddressSelected,
                onEndAddressSelected: widget.onEndAddressSelected,
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
                    final selected = type == widget.selectedActivity;
                    return GestureDetector(
                      onTap: () => widget.onActivitySelected(type),
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
        AnimatedPositioned(
          duration: _animDuration,
          curve: Curves.easeOutCubic,
          right: 16,
          bottom: sideControlsBottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleTool(icon: Icons.add, onTap: widget.onZoomIn),
              const SizedBox(height: 8),
              _CircleTool(icon: Icons.remove, onTap: widget.onZoomOut),
            ],
          ),
        ),
        AnimatedPositioned(
          duration: _animDuration,
          curve: Curves.easeOutCubic,
          left: 16,
          bottom: sideControlsBottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CircleTool(icon: Icons.delete_outline, onTap: widget.onClearRoutes),
              const SizedBox(height: 8),
              _CircleTool(icon: Icons.swap_horiz, onTap: widget.onSwitchRoutingType),
            ],
          ),
        ),
        AnimatedPositioned(
          duration: _animDuration,
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          bottom: controlsBottom,
          child: Center(
            child: _CircleTool(
              icon: Icons.my_location_rounded,
              onTap: widget.onCenterLocation,
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
