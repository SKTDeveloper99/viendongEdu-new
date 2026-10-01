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
  String time(String? value) {
    final s = value?.trim() ?? '';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  final matches = sessions.where(
    (s) =>
        s.sectionCode.trim() == sectionCode.trim() &&
        s.sessionDate.startsWith(date) &&
        time(s.startTime) == time(startTime) &&
        time(s.endTime) == time(endTime),
  );
  final iterator = matches.iterator;
  if (!iterator.moveNext()) return null;
  final match = iterator.current;
  return iterator.moveNext() ? null : match;
}
