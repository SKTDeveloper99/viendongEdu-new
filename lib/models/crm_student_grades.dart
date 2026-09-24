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
//   - No letter grade ('A'/'B'/'C'/'D'/'F') is stored anywhere in the CRM —
//     `gradeLetter` below is a CLIENT-SIDE display convention computed from
//     the numeric final_score using the standard 10-point Vietnamese scale
//     (>=8.5 A, >=7.0 B, >=5.5 C, >=4.0 D, else F). It is not sourced from
//     any grading authority and must not be treated as an official mark.
//   - No 4.0-scale GPA ("diem4") exists in the CRM; not shown (was already
//     dead/commented-out in the old screen).
//   - No cumulative-vs-term-only GPA distinction exists server-side; the
//     overview tab shows ONE average (10-point scale) for both instead of
//     inventing a second number.
//   - No total-program-credits figure exists as a single field. The overview
//     "X / Y tín chỉ" is approximated as
//     (credits of passed subjects) / (credits of passed subjects +
//     credits of remaining/not-yet-passed subjects from
//     /me/remaining-subjects) — i.e. only classes with a curriculum row see a
//     denominator at all; without a curriculum (`has_curriculum == false`)
//     the denominator falls back to the credits actually graded.

double? _numOrNull(dynamic v) => v == null ? null : (v as num).toDouble();

class CrmStudentGrade {
  final int? gradeId;
  final String? semesterCode;
  final String? classCode;
  final double? midtermScore;
  final double? finalExamScore;
  final double? finalScore;
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

  /// Quy ước hiển thị client-side — KHÔNG phải dữ liệu từ IMS/CRM (xem ghi
  /// chú đầu file).
  String get gradeLetter {
    if (finalScore == null) return '';
    final s = finalScore!;
    if (overridePass) return 'A';
    if (s >= 8.5) return 'A';
    if (s >= 7.0) return 'B';
    if (s >= 5.5) return 'C';
    if (s >= 4.0) return 'D';
    return 'F';
  }

  factory CrmStudentGrade.fromJson(Map<String, dynamic> j) => CrmStudentGrade(
    gradeId: (j['grade_id'] as num?)?.toInt(),
    semesterCode: j['semester_code']?.toString(),
    classCode: j['class_code']?.toString(),
    midtermScore: _numOrNull(j['midterm_score']),
    finalExamScore: _numOrNull(j['final_exam_score']),
    finalScore: _numOrNull(j['final_score']),
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
