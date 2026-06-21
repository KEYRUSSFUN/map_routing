import 'dart:convert';

/// Сообщение для пользователя, если запрос не дошёл до сервера.
String? userFacingNetworkError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('connection closed') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('timed out') ||
      text.contains('socketexception')) {
    return 'Сервер недоступен. Проверьте интернет и что backend запущен.';
  }
  if (text.contains('formatexception') &&
      (text.contains('<!doctype') || text.contains('<html'))) {
    return 'Сервер вернул некорректный ответ. Перезапустите backend из актуальной версии.';
  }
  return null;
}

Map<String, dynamic>? decodeJsonObject(String body) {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

String userFacingApiError({
  required int statusCode,
  required String body,
  String fallback = 'Ошибка сервера. Попробуйте позже.',
}) {
  final trimmed = body.trimLeft().toLowerCase();
  if (trimmed.startsWith('<!doctype') || trimmed.startsWith('<html')) {
    if (statusCode == 404) {
      return 'На сервере нет endpoint восстановления пароля. Перезапустите backend.';
    }
    return 'Сервер вернул HTML вместо JSON ($statusCode).';
  }

  final data = decodeJsonObject(body);
  final message = data?['message']?.toString();
  if (message != null && message.isNotEmpty) {
    return message;
  }

  return fallback;
}
