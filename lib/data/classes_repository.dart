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
  const SemesterClassesData({required this.sections, required this.grades});
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
    ]);
    return SemesterClassesData(
      sections: results[0] as List<CrmStudentSection>,
      grades: (results[1] as CrmStudentGradesView).grades,
    );
  }

  /// The student's own EMS attendance marks (all sections, latest 300).
  Future<List<EmsStudentMark>> attendance() =>
      AttendanceApi.myAttendance(limit: 300);
}
