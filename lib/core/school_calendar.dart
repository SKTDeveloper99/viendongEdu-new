/// School-calendar clock for Viễn Đông.
///
/// A school date is a calendar value in Asia/Ho_Chi_Minh (UTC+7), independent
/// of the phone's configured time zone. Vietnam does not observe DST, so a
/// fixed offset is sufficient and avoids adding a time-zone database solely
/// for this boundary.
class SchoolCalendar {
  SchoolCalendar({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const utcOffset = Duration(hours: 7);

  final DateTime Function() _clock;

  /// Current Vietnam wall time, represented as a field-only [DateTime].
  /// Consumers use its year/month/day/hour fields, not its time-zone flag.
  DateTime get now {
    final shifted = _clock().toUtc().add(utcOffset);
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  DateTime get today => dateOnly(now);
  String get todayIso => isoDate(today);

  /// Preserve an explicitly chosen calendar date by copying its fields.
  /// Never call `toUtc`/`toLocal` on date-picker or week-strip values.
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
