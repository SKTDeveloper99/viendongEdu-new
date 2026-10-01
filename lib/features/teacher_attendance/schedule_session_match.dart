import '../../models/ems_attendance_models.dart';

/// Resolves one selected schedule row to exactly one EMS session.
/// An absent or ambiguous match must never fall back to the generic list.
EmsSession? matchScheduleSession({
  required Iterable<EmsSession> sessions,
  required String sectionCode,
  required String date,
  required String startTime,
  required String endTime,
}) {
  final wantedDate = _sessionDate(date, allowTimestamp: false);
  if (wantedDate.isEmpty) return null;

  final matches = sessions.where(
    (s) =>
        s.sectionId.trim().isNotEmpty &&
        s.sessionKey.trim().isNotEmpty &&
        s.sectionCode.trim() == sectionCode.trim() &&
        _sessionDate(s.sessionDate) == wantedDate &&
        normalizeSchoolTime(s.startTime) == normalizeSchoolTime(startTime) &&
        normalizeSchoolTime(s.endTime) == normalizeSchoolTime(endTime) &&
        normalizeSchoolTime(s.startTime).isNotEmpty &&
        normalizeSchoolTime(s.endTime).isNotEmpty,
  );
  final iterator = matches.iterator;
  if (!iterator.moveNext()) return null;
  final match = iterator.current;
  return iterator.moveNext() ? null : match;
}

/// Normalizes a clock or timestamp to the wall time used by the Vietnam
/// school calendar. Explicitly zoned timestamps are converted to UTC+7;
/// unzoned schedule values retain their written wall-clock fields.
String normalizeSchoolTime(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return '';

  final hasZone = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(raw);
  if (hasZone) {
    final instant = DateTime.tryParse(raw);
    if (instant == null) return '';
    final hcm = instant.toUtc().add(const Duration(hours: 7));
    return _formatTime(hcm.hour, hcm.minute);
  }

  final match = RegExp(r'(?:[Tt ]|^)(\d{1,2}):(\d{2})').firstMatch(raw);
  if (match == null) return '';
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return '';
  return _formatTime(hour, minute);
}

String _formatTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

String _sessionDate(String raw, {bool allowTimestamp = true}) {
  final trimmed = raw.trim();
  final match = RegExp(
    allowTimestamp
        ? r'^(\d{4})-(\d{2})-(\d{2})(?=$|[Tt ])'
        : r'^(\d{4})-(\d{2})-(\d{2})$',
  ).firstMatch(trimmed);
  if (match == null) return '';
  if (trimmed.length > 10 && DateTime.tryParse(trimmed) == null) return '';
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return '';
  }
  return '${match.group(1)}-${match.group(2)}-${match.group(3)}';
}
