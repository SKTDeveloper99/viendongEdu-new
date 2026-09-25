// lib/models/crm_student_grades.dart — typed shapes for the CRM grade views
// that replace IMS `hocvien/bangdiemtongket`, `hocvien/thongkectdt`, and
// `hocvien/monhocchuadat`.
//
// Sources (crm-clean, read-only):
//   GET /api/student/me/grades              → { mssv, summary, grades }
//     lib/portals-student-portal-service.js#getGradesView
//     repositories/portals-student-portal-repo.js#getGrades
//   GET /api/student/me/remaining-subjects   → { mssv, has_curriculum,
//                                                 subjects, all_required_count,
//                                                 passed_count }
//     lib/portals-student-portal-service.js#getRemainingSubjectsView
//     repositories/portals-student-portal-repo.js#getRemainingSubjects
//
// Known gaps vs the old IMS shape (see docs/ims_to_crm_student_academic_map.md):
//   - `/me/grades` rows do not currently carry a `diem4` field, so the letter
//     grade is computed client-side FROM `final_score` — but using the
//     school's REAL ladder, ported byte-for-byte from crm-clean's
//     `lib/grades/diem4.js` (see `letterGradeForScore` below), not a generic
//     A/B/C/D/F guess. If a row ever does carry `diem4` (the server's own
//     4.0-scale conversion), that value is preferred and mapped to a letter
//     via `letterGradeForDiem4` instead of re-deriving from the raw score.
//   - No cumulative-vs-term-only GPA distinction exists server-side; the
//     overview tab shows ONE average (10-point scale) for both instead of
//     inventing a second number.
//   - The overview tab's "X / Y môn" (subject counts, not tín chỉ) comes
//     straight from `GET /api/student/me/graduation-summary`'s `academic`
//     block (see lib/models/crm_student_graduation_summary.dart) — no
//     client-side credit or average arithmetic any more.

double? _numOrNull(dynamic v) => v == null ? null : (v as num).toDouble();

/// 10-scale → letter grade, ported EXACTLY from crm-clean's
/// `lib/grades/diem4.js` (`toDiem4`) — Viễn Đông's real ladder (Thông tư
/// 08/2021/TT-BGDĐT, via Quy chế 43/2007), not a generic A/B/C/D/F guess:
///
///     10-scale       letter
///     8.5 – 10.0       A
///     8.0 – 8.4        B+
///     7.0 – 7.9        B
///     6.5 – 6.9        C+
///     5.5 – 6.4        C
///     5.0 – 5.4        D+
///     4.0 – 4.9        D
///     0.0 – 3.9        F
///
/// A null/non-finite score, or one outside [0, 10] (IMS carries out-of-range
/// garbage — diem4.js's own example is mssv 2408022005 / ELB21830
/// final_score 54.2), returns `null` — banding it would launder dirty data
/// into a fake grade. The caller shows "—", NEVER 'F', for `null`.
String? letterGradeForScore(double? score) {
  if (score == null || !score.isFinite) return null;
  if (score < 0 || score > 10) return null;
  if (score >= 8.5) return 'A';
  if (score >= 8.0) return 'B+';
  if (score >= 7.0) return 'B';
  if (score >= 6.5) return 'C+';
  if (score >= 5.5) return 'C';
  if (score >= 5.0) return 'D+';
  if (score >= 4.0) return 'D';
  return 'F';
}

/// Same ladder, entered from the 4.0-scale grade point instead of the raw
/// 10-scale score — for the day `/me/grades` starts carrying its own `diem4`
/// (crm-clean's generated column, migrations/060_grades_diem4.sql), which
/// must be preferred over re-deriving from `final_score`.
String? letterGradeForDiem4(double? diem4) {
  if (diem4 == null || !diem4.isFinite) return null;
  if (diem4 >= 4.0) return 'A';
  if (diem4 >= 3.5) return 'B+';
  if (diem4 >= 3.0) return 'B';
  if (diem4 >= 2.5) return 'C+';
  if (diem4 >= 2.0) return 'C';
  if (diem4 >= 1.5) return 'D+';
  if (diem4 >= 1.0) return 'D';
  if (diem4 >= 0.0) return 'F';
  return null;
}

class CrmStudentGrade {
  final int? gradeId;
  final String? semesterCode;
  final String? classCode;
  final double? midtermScore;
  final double? finalExamScore;
  final double? finalScore;
  /// Server-side 4.0-scale conversion — not present in today's /me/grades
  /// rows (fallback: `letterGradeForScore(finalScore)`), but preferred over
  /// it whenever the server does send it.
  final double? diem4;
  final String? status;
  final bool overridePass;
  final String? overrideNote;
  final DateTime? recordedAt;
  final int? subjectId;
  final String subjectCode;
  final String subjectName;
  final int credits;
  final int? sectionId;
  final String? sectionCode;
  final String teacherName;

  const CrmStudentGrade({
    this.gradeId,
    this.semesterCode,
    this.classCode,
    this.midtermScore,
    this.finalExamScore,
    this.finalScore,
    this.diem4,
    this.status,
    this.overridePass = false,
    this.overrideNote,
    this.recordedAt,
    this.subjectId,
    this.subjectCode = '',
    this.subjectName = '',
    this.credits = 0,
    this.sectionId,
    this.sectionCode,
    this.teacherName = '',
  });

  /// Chưa học/chưa có điểm — final_score còn null.
  bool get isUngraded => finalScore == null;

  /// Cùng luật với server (summarizeGrades ở
  /// lib/portals-student-portal-service.js): đạt khi final_score >= 5 hoặc
  /// được override_pass.
  bool get isPassed =>
      overridePass || (finalScore != null && finalScore! >= 5);

  /// Viễn Đông's real 8-band ladder (see `letterGradeForScore` at the top of
  /// this file) — prefers the server's own `diem4` when a row carries one.
  /// `null`/out-of-range/ungraded → '' (caller shows "—", never a fail).
  String get gradeLetter =>
      (diem4 != null ? letterGradeForDiem4(diem4) : letterGradeForScore(finalScore)) ?? '';

  factory CrmStudentGrade.fromJson(Map<String, dynamic> j) => CrmStudentGrade(
    gradeId: (j['grade_id'] as num?)?.toInt(),
    semesterCode: j['semester_code']?.toString(),
    classCode: j['class_code']?.toString(),
    midtermScore: _numOrNull(j['midterm_score']),
    finalExamScore: _numOrNull(j['final_exam_score']),
    finalScore: _numOrNull(j['final_score']),
    diem4: _numOrNull(j['diem4']),
    status: j['status']?.toString(),
    overridePass: j['override_pass'] == true,
    overrideNote: j['override_note']?.toString(),
    recordedAt: DateTime.tryParse(j['recorded_at']?.toString() ?? ''),
    subjectId: (j['subject_id'] as num?)?.toInt(),
    subjectCode: j['subject_code']?.toString() ?? '',
    subjectName: j['subject_name']?.toString() ?? '',
    credits: (j['credits'] as num?)?.toInt() ?? 0,
    sectionId: (j['section_id'] as num?)?.toInt(),
    sectionCode: j['section_code']?.toString(),
    teacherName: j['teacher_name']?.toString() ?? '',
  );
}

class CrmStudentGradesSummary {
  final int total;
  final int scored;
  final int passed;
  final int failed;
  final double? averageScore;

  const CrmStudentGradesSummary({
    this.total = 0,
    this.scored = 0,
    this.passed = 0,
    this.failed = 0,
    this.averageScore,
  });

  factory CrmStudentGradesSummary.fromJson(Map<String, dynamic> j) =>
      CrmStudentGradesSummary(
        total: (j['total'] as num?)?.toInt() ?? 0,
        scored: (j['scored'] as num?)?.toInt() ?? 0,
        passed: (j['passed'] as num?)?.toInt() ?? 0,
        failed: (j['failed'] as num?)?.toInt() ?? 0,
        averageScore: _numOrNull(j['average_score']),
      );
}

class CrmStudentGradesView {
  final String mssv;
  final CrmStudentGradesSummary summary;
  final List<CrmStudentGrade> grades;

  const CrmStudentGradesView({
    required this.mssv,
    required this.summary,
    this.grades = const [],
  });

  factory CrmStudentGradesView.fromJson(Map<String, dynamic> j) {
    final list = j['grades'];
    return CrmStudentGradesView(
      mssv: j['mssv']?.toString() ?? '',
      summary: CrmStudentGradesSummary.fromJson(
        (j['summary'] as Map<String, dynamic>?) ?? const {},
      ),
      grades: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(CrmStudentGrade.fromJson)
              .toList()
          : const [],
    );
  }
}

/// Một dòng trong `/me/remaining-subjects` — thay `hocvien/monhocchuadat`.
///
/// `completionStatus` giá trị thật từ server (repositories/
/// portals-student-portal-repo.js#getRemainingSubjects):
/// 'passed' | 'not_taken' | 'pending' | 'failed'.
class CrmRemainingSubject {
  final int? curriculumId;
  final String? semesterCode;
  final int? subjectId;
  final String subjectCode;
  final String subjectName;
  final int credits;
  final String completionStatus;
  final double? finalScore;

  const CrmRemainingSubject({
    this.curriculumId,
    this.semesterCode,
    this.subjectId,
    this.subjectCode = '',
    this.subjectName = '',
    this.credits = 0,
    this.completionStatus = 'not_taken',
    this.finalScore,
  });

  /// Nhãn tương đương `trangthai` cũ (0 chưa học / 1 đang học / 2 không đạt).
  String get statusLabel => switch (completionStatus) {
    'pending' => 'Đang học',
    'failed' => 'Không đạt',
    'passed' => 'Đạt',
    _ => 'Chưa học',
  };

  factory CrmRemainingSubject.fromJson(Map<String, dynamic> j) =>
      CrmRemainingSubject(
        curriculumId: (j['curriculum_id'] as num?)?.toInt(),
        semesterCode: j['semester_code']?.toString(),
        subjectId: (j['subject_id'] as num?)?.toInt(),
        subjectCode: j['subject_code']?.toString() ?? '',
        subjectName: j['subject_name']?.toString() ?? '',
        credits: (j['credits'] as num?)?.toInt() ?? 0,
        completionStatus: j['completion_status']?.toString() ?? 'not_taken',
        finalScore: _numOrNull(j['final_score']),
      );
}

class CrmRemainingSubjectsView {
  final String mssv;
  final bool hasCurriculum;
  final List<CrmRemainingSubject> subjects;
  final int allRequiredCount;
  final int passedCount;

  const CrmRemainingSubjectsView({
    required this.mssv,
    this.hasCurriculum = false,
    this.subjects = const [],
    this.allRequiredCount = 0,
    this.passedCount = 0,
  });

  factory CrmRemainingSubjectsView.fromJson(Map<String, dynamic> j) {
    final list = j['subjects'];
    return CrmRemainingSubjectsView(
      mssv: j['mssv']?.toString() ?? '',
      hasCurriculum: j['has_curriculum'] == true,
      subjects: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(CrmRemainingSubject.fromJson)
              .toList()
          : const [],
      allRequiredCount: (j['all_required_count'] as num?)?.toInt() ?? 0,
      passedCount: (j['passed_count'] as num?)?.toInt() ?? 0,
    );
  }
}
