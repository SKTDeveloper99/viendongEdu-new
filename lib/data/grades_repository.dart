import '../models/crm_student_grades.dart';
import '../models/crm_student_graduation_summary.dart';
import '../services/crm_student_api.dart';

/// What the grades screen needs from the server: per-subject rows
/// (`GET /api/student/me/grades`) and the graduation summary
/// (`GET /api/student/me/graduation-summary`, academic part only).
class GradesData {
  final CrmStudentGradesView grades;
  final CrmGraduationSummary summary;
  const GradesData({required this.grades, required this.summary});
}

/// Wraps the existing [CrmStudentApi] grade calls, unchanged: both requests
/// are fired together and any failure surfaces as the original exception.
class GradesRepository {
  const GradesRepository();

  Future<GradesData> load() async {
    final results = await Future.wait([
      CrmStudentApi.grades(),
      CrmStudentApi.graduationSummary(),
    ]);
    return GradesData(
      grades: results[0] as CrmStudentGradesView,
      summary: results[1] as CrmGraduationSummary,
    );
  }
}
