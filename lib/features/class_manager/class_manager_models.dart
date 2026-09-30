import '../../models/crm_teacher_class.dart';

/// A semester in the dropdown. Compared by identity, as before.
class ClassSemester {
  final int id;
  final String ma;
  final String ten;
  const ClassSemester({required this.id, required this.ma, required this.ten});
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

  SessionGroup({
    required this.sessionId,
    this.date,
    this.startTime,
    this.endTime,
    this.room,
  });
}

/// Per-student attendance totals folded from the CRM `attendance` rows
/// (not EMS — see [CrmAttendanceRow]).
class StudentAttendanceTotal {
  final String mssv;
  final String fullName;
  int total = 0;
  int present = 0;
  StudentAttendanceTotal({required this.mssv, required this.fullName});
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
  const SessionRowSummary({
    required this.marked,
    required this.pct,
    required this.countText,
  });
}
