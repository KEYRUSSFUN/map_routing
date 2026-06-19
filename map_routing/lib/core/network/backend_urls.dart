import 'package:map_routing/core/network/config.dart';

String? absoluteBackendUrl(String? raw) {
  if (raw == null) return null;

  var value = raw.trim();
  if (value.isEmpty || value == 'null') return null;

  // Иногда относительный путь ошибочно сохраняется/парсится как file:///api/...
  if (value.startsWith('file://')) {
    value = value.replaceFirst(RegExp(r'^file://+'), '');
    if (!value.startsWith('/')) {
      value = '/$value';
    }
  }

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  final base = backendBaseUrl.endsWith('/')
      ? backendBaseUrl.substring(0, backendBaseUrl.length - 1)
      : backendBaseUrl;

  if (value.startsWith('//')) {
    return 'http:$value';
  }

  if (value.startsWith('/')) {
    return '$base$value';
  }

  return '$base/$value';
}

bool isLoadableNetworkUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;
  return uri.scheme == 'http' || uri.scheme == 'https';
}
