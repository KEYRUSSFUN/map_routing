/// Parses API timestamps (stored in UTC) into local [DateTime].
DateTime parseBackendDateTime(
  dynamic raw, {
  DateTime? fallback,
}) {
  final fb = fallback ?? DateTime.now();
  if (raw == null) return fb;

  var str = raw.toString().trim();
  if (str.isEmpty) return fb;

  if (str.endsWith('Z')) {
    str = '${str.substring(0, str.length - 1)}+00:00';
  }

  final parsed = DateTime.tryParse(str);
  if (parsed == null) return fb;

  if (!parsed.isUtc && !_hasExplicitTimezoneOffset(raw.toString().trim())) {
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).toLocal();
  }

  return parsed.toLocal();
}

String formatBackendTime(dynamic raw) {
  final dt = parseBackendDateTime(raw);
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String backendNowIsoUtc() => DateTime.now().toUtc().toIso8601String();

bool _hasExplicitTimezoneOffset(String str) {
  return RegExp(r'([+-]\d{2}:?\d{2})$').hasMatch(str);
}
