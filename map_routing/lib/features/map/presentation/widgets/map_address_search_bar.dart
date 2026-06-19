import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/models/address_suggestion.dart';
import 'package:map_routing/data/services/yandex_address_suggest_service.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' hide Icon, Overlay;
import 'package:yandex_maps_mapkit/search.dart';

class MapAddressSearchBar extends StatefulWidget {
  const MapAddressSearchBar({
    super.key,
    required this.searchService,
    required this.getSearchBounds,
    this.getUserPosition,
    required this.onAddressSelected,
    this.onStartAddressSelected,
    this.onEndAddressSelected,
    this.onFocusChanged,
  });

  final YandexAddressSuggestService searchService;
  final BoundingBox Function() getSearchBounds;
  final Point? Function()? getUserPosition;
  final ValueChanged<AddressSuggestion> onAddressSelected;
  final ValueChanged<AddressSuggestion>? onStartAddressSelected;
  final ValueChanged<AddressSuggestion>? onEndAddressSelected;
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<MapAddressSearchBar> createState() => _MapAddressSearchBarState();
}

class _MapAddressSearchBarState extends State<MapAddressSearchBar> {
  var _routeFieldsExpanded = false;
  final _singleFieldKey = GlobalKey<_AddressSearchFieldState>();
  final _startFieldKey = GlobalKey<_AddressSearchFieldState>();
  final _endFieldKey = GlobalKey<_AddressSearchFieldState>();

  void _toggleRouteFields() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _routeFieldsExpanded = !_routeFieldsExpanded);
  }

  @override
  Widget build(BuildContext context) {
    if (_routeFieldsExpanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _AddressSearchField(
            key: _startFieldKey,
            hintText: 'Откуда — адрес начала',
            leadingIcon: Icons.radio_button_checked,
            leadingIconColor: MapUiColors.primaryGreen,
            searchService: widget.searchService,
            getSearchBounds: widget.getSearchBounds,
            getUserPosition: widget.getUserPosition,
            onAddressSelected: widget.onStartAddressSelected ?? widget.onAddressSelected,
            onFocusChanged: widget.onFocusChanged,
            trailing: _RouteFieldsToggleButton(
              expanded: true,
              onTap: _toggleRouteFields,
            ),
          ),
          const SizedBox(height: 8),
          _AddressSearchField(
            key: _endFieldKey,
            hintText: 'Куда — адрес назначения',
            leadingIcon: Icons.location_on_outlined,
            leadingIconColor: MapUiColors.stopRed,
            searchService: widget.searchService,
            getSearchBounds: widget.getSearchBounds,
            getUserPosition: widget.getUserPosition,
            onAddressSelected: widget.onEndAddressSelected ?? widget.onAddressSelected,
            onFocusChanged: widget.onFocusChanged,
          ),
        ],
      );
    }

    return _AddressSearchField(
      key: _singleFieldKey,
      hintText: 'Поиск адреса...',
      leadingIcon: Icons.search_rounded,
      searchService: widget.searchService,
      getSearchBounds: widget.getSearchBounds,
      getUserPosition: widget.getUserPosition,
      onAddressSelected: widget.onAddressSelected,
      onFocusChanged: widget.onFocusChanged,
      trailing: _RouteFieldsToggleButton(
        expanded: false,
        onTap: _toggleRouteFields,
      ),
    );
  }
}

class _RouteFieldsToggleButton extends StatelessWidget {
  const _RouteFieldsToggleButton({
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        expanded ? Icons.close_rounded : Icons.tune_rounded,
        color: MapUiColors.primaryGreen,
        size: 22,
      ),
    );
  }
}

class _AddressSearchField extends StatefulWidget {
  const _AddressSearchField({
    super.key,
    required this.hintText,
    required this.leadingIcon,
    required this.searchService,
    required this.getSearchBounds,
    required this.onAddressSelected,
    this.getUserPosition,
    this.leadingIconColor,
    this.trailing,
    this.onFocusChanged,
  });

  final String hintText;
  final IconData leadingIcon;
  final Color? leadingIconColor;
  final YandexAddressSuggestService searchService;
  final BoundingBox Function() getSearchBounds;
  final Point? Function()? getUserPosition;
  final ValueChanged<AddressSuggestion> onAddressSelected;
  final Widget? trailing;
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<_AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<_AddressSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _barKey = GlobalKey();
  Timer? _debounce;
  OverlayEntry? _overlayEntry;
  var _suggestions = <AddressSuggestion>[];
  var _isLoading = false;
  var _requestId = 0;

  bool get _showSuggestions =>
      _focusNode.hasFocus && (_suggestions.isNotEmpty || _isLoading);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _overlayEntry?.markNeedsBuild();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onControllerChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void closeSuggestions() {
    if (!_focusNode.hasFocus) return;
    _focusNode.unfocus();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
    if (!_focusNode.hasFocus) {
      setState(() => _suggestions = []);
      _removeOverlay();
    } else if (_controller.text.trim().isNotEmpty) {
      _requestSuggestions(_controller.text);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _requestSuggestions(value);
    });
  }

  void _requestSuggestions(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _syncOverlay();
      return;
    }

    final requestId = ++_requestId;
    setState(() => _isLoading = true);
    _syncOverlay();

    widget.searchService.suggest(
      text: trimmed,
      window: widget.getSearchBounds(),
      userPosition: widget.getUserPosition?.call(),
      onResult: (suggestions) {
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
        _syncOverlay();
      },
    );
  }

  void _syncOverlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_showSuggestions) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final renderBox =
            _barKey.currentContext?.findRenderObject() as RenderBox?;
        final width = renderBox?.size.width ??
            MediaQuery.sizeOf(overlayContext).width - 24;
        final targetTop = renderBox?.localToGlobal(Offset.zero).dy ?? 0;

        return _SuggestionsOverlay(
          layerLink: _layerLink,
          dropdownWidth: width,
          targetTop: targetTop,
          isLoading: _isLoading,
          suggestions: _suggestions,
          onDismiss: () => _focusNode.unfocus(),
          onSuggestionTap: _onSuggestionTap,
        );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _onSuggestionTap(AddressSuggestion suggestion) async {
    if (suggestion.action == SuggestItemAction.Substitute) {
      _controller.text = suggestion.searchText;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      _requestSuggestions(suggestion.searchText);
      return;
    }

    _focusNode.unfocus();
    _removeOverlay();
    setState(() {
      _suggestions = [];
      _controller.text = suggestion.title;
    });
    widget.onAddressSelected(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        key: _barKey,
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              widget.leadingIcon,
              size: 22,
              color: widget.leadingIconColor ??
                  MapUiColors.body.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: 1,
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  height: 1.2,
                  color: MapUiColors.title,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  isCollapsed: true,
                  hintText: widget.hintText,
                  hintStyle: GoogleFonts.lexendDeca(
                    fontSize: 14,
                    height: 1.2,
                    color: MapUiColors.body,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (value) {
                  if (_suggestions.isNotEmpty) {
                    _onSuggestionTap(_suggestions.first);
                  }
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _controller.clear();
                  setState(() => _suggestions = []);
                  _removeOverlay();
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: MapUiColors.body.withValues(alpha: 0.7),
                  ),
                ),
              ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 8),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionsOverlay extends StatelessWidget {
  const _SuggestionsOverlay({
    required this.layerLink,
    required this.dropdownWidth,
    required this.targetTop,
    required this.isLoading,
    required this.suggestions,
    required this.onDismiss,
    required this.onSuggestionTap,
  });

  final LayerLink layerLink;
  final double dropdownWidth;
  final double targetTop;
  final bool isLoading;
  final List<AddressSuggestion> suggestions;
  final VoidCallback onDismiss;
  final ValueChanged<AddressSuggestion> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final keyboardInset = view.viewInsets.bottom / view.devicePixelRatio;
    final maxHeight = math.max(
      120.0,
      MediaQuery.sizeOf(context).height - targetTop - 54 - keyboardInset - 24,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.translucent,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 54),
          child: Material(
            elevation: 12,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.98),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dropdownWidth,
                maxHeight: math.min(maxHeight, 280),
              ),
              child: isLoading && suggestions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 48,
                        color: MapUiColors.body.withValues(alpha: 0.12),
                      ),
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        return InkWell(
                          onTap: () => onSuggestionTap(suggestion),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  suggestion.isWordItem
                                      ? Icons.search_rounded
                                      : Icons.location_on_outlined,
                                  color: MapUiColors.primaryGreen,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        suggestion.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.lexendDeca(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: MapUiColors.title,
                                        ),
                                      ),
                                      if (suggestion.subtitle != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          suggestion.subtitle!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.lexendDeca(
                                            fontSize: 12,
                                            color: MapUiColors.body,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
