import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/search.dart';

class AddressSuggestion {
  const AddressSuggestion({
    required this.title,
    this.subtitle,
    required this.searchText,
    this.center,
    this.uri,
    this.action = SuggestItemAction.Search,
    this.isWordItem = false,
  });

  final String title;
  final String? subtitle;
  final String searchText;
  final Point? center;
  final String? uri;
  final SuggestItemAction action;
  final bool isWordItem;
}
