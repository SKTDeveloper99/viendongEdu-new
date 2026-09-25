// lib/models/crm_student_graduation_summary.dart — typed shape of
// `GET /api/student/me/graduation-summary`, which replaces the client-side
// arithmetic the overview tab used to do over /me/grades +
// /me/remaining-subjects.
//
// Source (crm-clean, read-only): routes/portals/student-portal.js:91,
// lib/portals-student-portal-service.js#getGraduationSummary (and the
// `summarizeGrades` helper it calls, same file, line ~58).
//
// DELIBERATE scope cut: the real response also carries `tuition` and a
// `financially_clear`/`can_graduate` pair inside `eligibility` — money data,
// owned by another bot's screens (tuition_screen.dart / lephi_screen.dart)
// and out of this slice per the brief. This model parses ONLY the academic
// half (`academic`, `remaining_subjects`) and the academic half of
// `eligibility`; the tuition/finance fields are left unparsed on purpose,
// not because they are missing from the server response.
//
// `academic` is SUBJECT-COUNT based (total/scored/passed/failed,
// required_subjects/required_passed), not a credit-hour sum — the server's
// `summarizeGrades()` counts grade ROWS, it does not sum `credits`. The old
// IMS `thongkectdt` reported tín chỉ (credit-hours); there is no credit-hour
// total anywhere in this endpoint, so the overview tab shows "X/Y môn"
// (subjects), not tín chỉ, rather than inventing a credit total the server
// never computed. Documented in docs/ims_to_crm_student_academic_map.md.
import 'crm_student_grades.dart';

class CrmAcademicSummary {
  final int total;
  final int scored;
  final int passed;
  final int failed;
  final double? averageScore;
  final bool hasCurriculum;
  final int requiredSubjects;
  final int requiredPassed;
  final int remainingSubjectsCount;
  final bool academicallyClear;

  const CrmAcademicSummary({
    this.total = 0,
    this.scored = 0,
    this.passed = 0,
    this.failed = 0,
    this.averageScore,
    this.hasCurriculum = false,
    this.requiredSubjects = 0,
    this.requiredPassed = 0,
    this.remainingSubjectsCount = 0,
    this.academicallyClear = false,
  });

  factory CrmAcademicSummary.fromJson(Map<String, dynamic> j) =>
      CrmAcademicSummary(
        total: (j['total'] as num?)?.toInt() ?? 0,
        scored: (j['scored'] as num?)?.toInt() ?? 0,
        passed: (j['passed'] as num?)?.toInt() ?? 0,
        failed: (j['failed'] as num?)?.toInt() ?? 0,
        averageScore: (j['average_score'] as num?)?.toDouble(),
        hasCurriculum: j['has_curriculum'] == true,
        requiredSubjects: (j['required_subjects'] as num?)?.toInt() ?? 0,
        requiredPassed: (j['required_passed'] as num?)?.toInt() ?? 0,
        remainingSubjectsCount:
            (j['remaining_subjects_count'] as num?)?.toInt() ?? 0,
        academicallyClear: j['academically_clear'] == true,
      );
}

class CrmGraduationSummary {
  final CrmAcademicSummary academic;
  final List<CrmRemainingSubject> remainingSubjects;

  const CrmGraduationSummary({
    required this.academic,
    this.remainingSubjects = const [],
  });

  factory CrmGraduationSummary.fromJson(Map<String, dynamic> j) {
    final list = j['remaining_subjects'];
    return CrmGraduationSummary(
      academic: CrmAcademicSummary.fromJson(
        (j['academic'] as Map<String, dynamic>?) ?? const {},
      ),
      remainingSubjects: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(CrmRemainingSubject.fromJson)
              .toList()
          : const [],
    );
  }
}
