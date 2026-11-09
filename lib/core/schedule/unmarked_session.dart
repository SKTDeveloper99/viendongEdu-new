/// What a student's class session with no attendance mark means, by date.
///
/// One rule for Lịch học, the class detail chart and session list, and the
/// Điểm danh screen, so no screen calls a future class "Chưa điểm danh" or a
/// silent past one absent:
/// - a later day: [upcoming] ("Sắp tới");
/// - today: [awaiting] ("Chờ điểm danh"), the teacher may still mark it;
/// - an earlier day: [noData] ("Chưa có dữ liệu"). Never counted as absent,
///   never drawn in red, and left out of the presence percentage.
///
/// A failed read is not one of these: screens keep "Chưa tải được" for it.
library;

enum UnmarkedSession { upcoming, awaiting, noData }

/// [day] and [now] are compared as local calendar dates only.
UnmarkedSession unmarkedSessionOn(DateTime day, DateTime now) {
  final d = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  if (d.isAfter(today)) return UnmarkedSession.upcoming;
  if (d.isAtSameMomentAs(today)) return UnmarkedSession.awaiting;
  return UnmarkedSession.noData;
}

/// `yyyy-MM-dd` (optionally followed by a time) to a local date; null if not.
DateTime? sessionDay(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw.trim());
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

extension UnmarkedSessionLabel on UnmarkedSession {
  String get label => switch (this) {
    UnmarkedSession.upcoming => 'Sắp tới',
    UnmarkedSession.awaiting => 'Chờ điểm danh',
    UnmarkedSession.noData => 'Chưa có dữ liệu',
  };

  /// Status key used by the schedule card badge.
  String get statusKey => switch (this) {
    UnmarkedSession.upcoming => 'upcoming',
    UnmarkedSession.awaiting => 'awaiting',
    UnmarkedSession.noData => 'nodata',
  };
}
