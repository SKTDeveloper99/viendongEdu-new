import '../../models/crm_student_grades.dart';

// Wraps a CrmStudentGrade (GET /api/student/me/grades) with the field names
// the widgets use. `gradeLetter`/`isPassed` are computed on CrmStudentGrade
// itself using the school's real 8-band ladder (lib/models/crm_student_grades.dart,
// letterGradeForScore — ported from crm-clean's lib/grades/diem4.js).
class GradeItem {
  final CrmStudentGrade grade;
  final int solan;
  const GradeItem(this.grade, {this.solan = 1});

  String get mhma => grade.subjectCode;
  String get mhten => grade.subjectName;
  int get sotinchi => grade.credits;
  double get tongdiem => grade.finalScore ?? 0;
  // '' (chưa có điểm, hoặc điểm ngoài [0,10] — không băng được) → "—", KHÔNG
  // BAO GIỜ hiện như một điểm rớt.
  String get diemchu => grade.gradeLetter.isEmpty ? '—' : grade.gradeLetter;
  bool get datyn => grade.isPassed;
  bool get chuaHoc => grade.isUngraded; // tongdiem null → chưa có điểm
}

/// A curriculum subject the student has not passed yet. [status] keeps the
/// legacy `trangthai` codes: 0 chưa học, 1 đang học, 2 không đạt.
class RemainingSubjectItem {
  final String code;
  final String name;
  final int credits;
  final int status;
  const RemainingSubjectItem({
    required this.code,
    required this.name,
    required this.credits,
    required this.status,
  });
}

/// Gán "Lần N" theo thứ tự thời gian thật (semester_code rồi recorded_at) khi
/// một môn xuất hiện nhiều lần trong /me/grades (học lại) — /me/grades không
/// tự đánh số lần như IMS `bangdiemtongket` từng làm, nên tính lại ở client
/// từ chính danh sách server trả về (không suy đoán, không thêm dữ liệu).
List<GradeItem> withRetakeNumbers(List<CrmStudentGrade> grades) {
  final bySubject = <String, List<CrmStudentGrade>>{};
  for (final g in grades) {
    bySubject.putIfAbsent(g.subjectCode, () => []).add(g);
  }
  for (final list in bySubject.values) {
    list.sort((a, b) {
      final sa = a.semesterCode ?? '';
      final sb = b.semesterCode ?? '';
      final c = sa.compareTo(sb);
      if (c != 0) return c;
      final ra = a.recordedAt ?? DateTime(0);
      final rb = b.recordedAt ?? DateTime(0);
      return ra.compareTo(rb);
    });
  }
  final solanFor = <CrmStudentGrade, int>{};
  for (final list in bySubject.values) {
    for (var i = 0; i < list.length; i++) {
      solanFor[list[i]] = i + 1;
    }
  }
  return grades.map((g) => GradeItem(g, solan: solanFor[g] ?? 1)).toList();
}
