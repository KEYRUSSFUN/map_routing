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
  return null;
}
