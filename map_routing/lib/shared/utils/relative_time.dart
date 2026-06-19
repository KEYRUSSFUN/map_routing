String formatRelativeTimeRu(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime.toLocal());

  if (diff.inMinutes < 1) return 'только что';
  if (diff.inMinutes < 60) {
    final minutes = diff.inMinutes;
    return '$minutes ${_ruMinutes(minutes)} назад';
  }
  if (diff.inHours < 24) {
    final hours = diff.inHours;
    return '$hours ${_ruHours(hours)} назад';
  }
  if (diff.inDays < 7) {
    final days = diff.inDays;
    return '$days ${_ruDays(days)} назад';
  }

  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
}

String _ruMinutes(int value) {
  final mod10 = value % 10;
  final mod100 = value % 100;
  if (mod10 == 1 && mod100 != 11) return 'минуту';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'минуты';
  }
  return 'минут';
}

String _ruHours(int value) {
  final mod10 = value % 10;
  final mod100 = value % 100;
  if (mod10 == 1 && mod100 != 11) return 'час';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'часа';
  }
  return 'часов';
}

String _ruDays(int value) {
  final mod10 = value % 10;
  final mod100 = value % 100;
  if (mod10 == 1 && mod100 != 11) return 'день';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'дня';
  }
  return 'дней';
}

String formatCommentsCountRu(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod100 >= 11 && mod100 <= 14) return '$count комментариев';
  if (mod10 == 1) return '$count комментарий';
  if (mod10 >= 2 && mod10 <= 4) return '$count комментария';
  return '$count комментариев';
}
