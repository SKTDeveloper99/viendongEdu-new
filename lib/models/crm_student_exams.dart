// lib/models/crm_student_exams.dart — typed shape of
// `GET /api/student/me/exams`, which replaces IMS `hocvien/lichthi`.
//
// Source (crm-clean, read-only worktree
// .claude/worktrees/agent-a86dcd5eb8ad283d1):
//   routes/portals/student-exams.js, lib/portals-exams-service.js,
//   repositories/portals-exams-repo.js. Contract documented in
//   docs/api/mobile-ims-replacement-S3.md, which also names three gaps this
//   model must not paper over:
//     1. `room` is frequently null (IMS data-quality issue, not a join bug).
//     2. `exam_format` is present in the shape but not populated in the
//        sample — kept nullable, shown only when present.
//     3. Data freshness is the nightly ims_snapshot mirror (worst case ~24h
//        stale) — same as every other IMS-backed CRM read.
class CrmStudentExam {
  final String examId;
  final DateTime? examDate;
  final String startTime;
  final int durationMinutes;
  final String examType;
  final String? examFormat;
  final String? examGroup;
  final String? note;
  final String? room;
  final String? classCode;
  final String subjectCode;
  final String subjectName;
  final int? credits;
  final String semesterCode;
  final String? semesterName;

  const CrmStudentExam({
    required this.examId,
    this.examDate,
    this.startTime = '',
    this.durationMinutes = 0,
    this.examType = '',
    this.examFormat,
    this.examGroup,
    this.note,
    this.room,
    this.classCode,
    this.subjectCode = '',
    this.subjectName = '',
    this.credits,
    this.semesterCode = '',
    this.semesterName,
  });

  String get examDateFormatted {
    final d = examDate;
    if (d == null) return '–';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  factory CrmStudentExam.fromJson(Map<String, dynamic> j) => CrmStudentExam(
    examId: j['exam_id']?.toString() ?? '',
    examDate: DateTime.tryParse(j['exam_date']?.toString() ?? ''),
    startTime: j['start_time']?.toString() ?? '',
    durationMinutes: int.tryParse('${j['duration_minutes'] ?? 0}') ?? 0,
    examType: j['exam_type']?.toString() ?? '',
    examFormat: j['exam_format']?.toString(),
    examGroup: j['exam_group']?.toString(),
    note: j['note']?.toString(),
    room: j['room']?.toString(),
    classCode: j['class_code']?.toString(),
    subjectCode: j['subject_code']?.toString() ?? '',
    subjectName: j['subject_name']?.toString() ?? '',
    credits: int.tryParse('${j['credits'] ?? ''}'),
    semesterCode: j['semester_code']?.toString() ?? '',
    semesterName: j['semester_name']?.toString(),
  );
}

class CrmStudentExamsView {
  final String semesterCode;
  final List<CrmStudentExam> exams;

  const CrmStudentExamsView({required this.semesterCode, this.exams = const []});

  factory CrmStudentExamsView.fromJson(Map<String, dynamic> j) {
    final list = j['exams'];
    return CrmStudentExamsView(
      semesterCode: j['semester_code']?.toString() ?? '',
      exams: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(CrmStudentExam.fromJson)
              .toList()
          : const [],
    );
  }
}

/// Nhãn học kỳ hiển thị được cho người dùng, suy ra từ `semester_code`
/// (dạng "YYS": 2 số năm + 1 số kỳ, S=1|2 hoặc 3=hè) — vì CRM KHÔNG có
/// endpoint /me/semesters cho học viên (chỉ giảng viên có
/// GET /api/teacher/me/semesters). Suy luận này dựa trên đúng mẫu thật trong
/// docs/api/mobile-ims-replacement-S3.md ("253" → "Học kỳ hè, 2025 - 2026")
/// và CLAUDE.md ("261 = K20 HK1, Sept 2026"); được ghi lại là một GIẢ ĐỊNH
/// trong docs/ims_to_crm_student_academic_map.md, không phải một hợp đồng
/// server.
String semesterCodeLabel(String code) {
  final m = RegExp(r'^(\d{2})(\d)$').firstMatch(code);
  if (m == null) return code.isEmpty ? '–' : code;
  final year = 2000 + int.parse(m.group(1)!);
  final sem = m.group(2);
  final range = '$year - ${year + 1}';
  return switch (sem) {
    '1' => 'Học kỳ 1, $range',
    '2' => 'Học kỳ 2, $range',
    '3' => 'Học kỳ hè, $range',
    _ => 'Học kỳ $sem, $range',
  };
}
