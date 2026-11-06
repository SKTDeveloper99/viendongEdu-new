import '../../models/crm_teacher_class.dart';

/// A semester in the dropdown. Compared by identity, as before.
class ClassSemester {
  final int id;
  final String ma;
  final String ten;
  final String? ngayBatDau;
  const ClassSemester({
    required this.id,
    required this.ma,
    required this.ten,
    this.ngayBatDau,
  });
}

/// One session, built by grouping the flat rows of
/// `GET /me/classes/:id/attendance` by `session_id`.
class SessionGroup {
  final String sessionId;
  final String? date;
  final String? startTime;
  final String? endTime;
  final String? room;
  final List<CrmAttendanceRow> students = [];

  /// Buổi dự kiến (tương lai), không có điểm danh.
  final bool planned;

  /// "Buổi N" theo thứ tự ngày (từ 1); 0 khi chưa đánh số.
  int number = 0;

  SessionGroup({
    required this.sessionId,
    this.date,
    this.startTime,
    this.endTime,
    this.room,
    this.planned = false,
  });
}

/// Per-student attendance totals folded from the CRM `attendance` rows
/// (not EMS — see [CrmAttendanceRow]).
class StudentAttendanceTotal {
  final String mssv;
  final String fullName;

  /// Due sessions with a known mark (EMS, else CRM); unmarked ones excluded.
  int total = 0;
  int present = 0;
  StudentAttendanceTotal({required this.mssv, required this.fullName});

  /// "3/5", or "N/A" when no due session has a mark for this student.
  String get countText => total > 0 ? '$present/$total' : 'N/A';
}

/// EMS marks of one session: present-like count and total marked rows.
class EmsSessionCount {
  final int present;
  final int total;
  const EmsSessionCount({required this.present, required this.total});
}

/// What one row of the "Buổi học" list displays, exactly as before.
class SessionRowSummary {
  final bool marked; // EMS has marks for the session
  final double pct;
  final String countText;

  /// Planned future session: shown muted as "Sắp tới".
  final bool planned;
  const SessionRowSummary({
    required this.marked,
    required this.pct,
    required this.countText,
    this.planned = false,
  });
}
