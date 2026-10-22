import '../models/crm_student_grades.dart';
import '../models/crm_student_schedule.dart';
import '../services/crm_student_api.dart';
import '../services/ems_api_service.dart';
import 'api/attendance_api.dart';

/// Enrolment rows of one semester plus the student's grade rows, as fetched
/// together when a semester is opened.
class SemesterClassesData {
  final List<CrmStudentSection> sections;
  final List<CrmStudentGrade> grades;

  /// section_code -> last date of its official timetable (tkb.ngayketthuc);
  /// empty when the timetable could not be read.
  final Map<String, DateTime> timetableEnd;
  const SemesterClassesData({
    required this.sections,
    required this.grades,
    this.timetableEnd = const {},
  });
}

/// Wraps the existing calls the classes screens make, unchanged:
/// `GET /api/student/me/sections[?semester=]`, `GET /api/student/me/grades`
/// and the EMS attendance history (`GET /api/student/me/attendance-ems`).
/// Any failure surfaces as the original exception.
class ClassesRepository {
  const ClassesRepository();

  /// Every enrolment (no semester filter) — the semester list is derived
  /// from it.
  Future<List<CrmStudentSection>> allSections() => CrmStudentApi.sections();

  /// Sections of [semester] and the grade rows, requested together.
  Future<SemesterClassesData> semesterClasses(String semester) async {
    final results = await Future.wait([
      CrmStudentApi.sections(semester: semester),
      CrmStudentApi.grades(),
      // Optional: a timetable failure only leaves the end date N/A.
      CrmStudentApi.schedule(
        semester: semester,
      ).catchError((Object _) => <CrmScheduleItem>[]),
    ]);
    final ends = <String, DateTime>{};
    for (final t in results[2] as List<CrmScheduleItem>) {
      final d = t.endDate;
      if (t.sectionCode.isEmpty || d == null) continue;
      final cur = ends[t.sectionCode];
      if (cur == null || d.isAfter(cur)) ends[t.sectionCode] = d;
    }
    return SemesterClassesData(
      sections: results[0] as List<CrmStudentSection>,
      grades: (results[1] as CrmStudentGradesView).grades,
      timetableEnd: ends,
    );
  }

  /// The student's own EMS attendance marks (all sections, latest 300).
  Future<List<EmsStudentMark>> attendance() =>
      AttendanceApi.myAttendance(limit: 300);
}
