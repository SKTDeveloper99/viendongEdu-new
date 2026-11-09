/// Server notices on student screens (contract S3,
/// `contract-student-notices-and-support.md`).
///
/// A top-level `notices` array of `{id, level, text, until?}` may ride on
/// `/student/me`, `/me/tuition`, `/me/schedule`, `/me/exams`, `/me/grades`,
/// `/me/attendance-ems` and `/me/sections`. The server decides what goes where;
/// the app draws every visible notice in array order. A missing, null or
/// malformed field is an empty list, never an error and never a placeholder.
library;

enum StudentNoticeLevel { info, warning, urgent }

class StudentNotice {
  final String id;
  final StudentNoticeLevel level;
  final String text;

  /// Last Vietnam calendar day the notice is shown; null = no end date.
  final DateTime? until;

  const StudentNotice({
    required this.id,
    required this.level,
    required this.text,
    this.until,
  });

  /// Shown on [vnToday] (a Vietnam calendar date) unless its `until` is past.
  bool visibleOn(DateTime vnToday) {
    final u = until;
    if (u == null) return true;
    final today = DateTime(vnToday.year, vnToday.month, vnToday.day);
    return !today.isAfter(u);
  }

  /// Null when the entry has no usable text (it is then skipped).
  static StudentNotice? tryParse(Object? raw, int index) {
    if (raw is! Map) return null;
    final text = raw['text'];
    if (text is! String || text.trim().isEmpty) return null;
    final id = raw['id'];
    return StudentNotice(
      id: id is String && id.isNotEmpty ? id : 'notice-$index',
      level: switch (raw['level']) {
        'urgent' => StudentNoticeLevel.urgent,
        'warning' => StudentNoticeLevel.warning,
        _ => StudentNoticeLevel.info,
      },
      text: text.trim(),
      until: _parseDay(raw['until']),
    );
  }
}

final RegExp _day = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

DateTime? _parseDay(Object? raw) {
  if (raw is! String) return null;
  final m = _day.firstMatch(raw.trim());
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final date = DateTime(y, mo, d);
  // Reject impossible dates such as 2026-02-31 instead of rolling them over.
  if (date.year != y || date.month != mo || date.day != d) return null;
  return date;
}

/// Every well-formed notice in `body['notices']`, in server order.
List<StudentNotice> parseStudentNotices(Object? body) {
  final raw = body is Map ? body['notices'] : null;
  if (raw is! List) return const [];
  final out = <StudentNotice>[];
  for (var i = 0; i < raw.length; i++) {
    final n = StudentNotice.tryParse(raw[i], i);
    if (n != null) out.add(n);
  }
  return List.unmodifiable(out);
}

/// Today's calendar date in Vietnam (UTC+7), whatever the phone's time zone.
DateTime vietnamToday([DateTime? now]) {
  final vn = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  return DateTime(vn.year, vn.month, vn.day);
}

/// The notices to draw right now, in server order.
List<StudentNotice> visibleStudentNotices(
  List<StudentNotice> notices, [
  DateTime? now,
]) {
  final today = vietnamToday(now);
  return [
    for (final n in notices)
      if (n.visibleOn(today)) n,
  ];
}
