import 'package:flutter/foundation.dart';

import '../../data/classes_repository.dart';
import '../../models/crm_student_exams.dart' show semesterCodeLabel;
import '../../models/crm_student_grades.dart';
import '../../services/ems_api_service.dart';
import 'class_models.dart';

/// State of the classes list: the semesters derived from the enrolments and
/// the classes (with scores) of the selected semester.
class ClassesViewModel extends ChangeNotifier {
  final ClassesRepository _repository;

  ClassesViewModel(this._repository);

  List<ClassSemester> _semesters = [];
  List<ClassItem> _classes = [];
  ClassSemester? _selected;
  bool _loading = true;
  bool _loadingClasses = false;
  String? _error;
  Object? _authError;
  bool _disposed = false;

  List<ClassSemester> get semesters => _semesters;
  List<ClassItem> get classes => _classes;
  ClassSemester? get selected => _selected;
  bool get loading => _loading;
  bool get loadingClasses => _loadingClasses;
  String? get error => _error;

  /// True when the last request failed with HTTP 401; the view reacts by
  /// calling `handleCrmAuthError` with [authError].
  bool get unauthorized => _authError != null;
  Object? get authError => _authError;

  /// Loads the semester list, then opens the newest one. Also "Thử lại".
  Future<void> fetchSemesters() async {
    _loading = true;
    _error = null;
    _authError = null;
    notifyListeners();
    try {
      // Không lọc theo semester để lấy đủ lịch sử ghi danh, rồi rút ra danh
      // sách học kỳ duy nhất từ đó.
      final sections = await _repository.allSections();
      final seen = <String>{};
      final sems = <ClassSemester>[];
      for (final s in sections) {
        final code = s.semesterCode;
        if (code == null || code.isEmpty || !seen.add(code)) continue;
        sems.add(ClassSemester(code: code, ten: semesterCodeLabel(code)));
      }
      // Mới nhất trước (mã học kỳ lớn hơn = mới hơn).
      sems.sort((a, b) => b.code.compareTo(a.code));
      if (_disposed) return;
      _semesters = sems;
      _loading = false;
      notifyListeners();
      if (sems.isNotEmpty) await selectSemester(sems.first);
    } catch (e) {
      if (_disposed) return;
      _loading = false;
      _error = e.toString();
      _flagAuth(e);
      notifyListeners();
    }
  }

  /// Opens [sem]: fetches its sections and attaches midterm/final/total
  /// scores. A failure leaves the list empty (no error state), as before.
  Future<void> selectSemester(ClassSemester sem) async {
    _selected = sem;
    _loadingClasses = true;
    _classes = [];
    _authError = null;
    notifyListeners();
    try {
      final data = await _repository.semesterClasses(sem.code);
      if (_disposed) return;
      final grades = data.grades;
      // Khớp theo section_code, rồi rơi về subject_code + học kỳ khi một dòng
      // điểm không có section_code — xảy ra với ~2.900 dòng điểm nhập tay
      // không có LMH đứng sau (ADR 004 trong crm-clean).
      _classes = data.sections.map((s) {
        CrmStudentGrade? g = grades.cast<CrmStudentGrade?>().firstWhere(
              (g) => g?.sectionCode == s.sectionCode,
              orElse: () => null,
            );
        g ??= grades.cast<CrmStudentGrade?>().firstWhere(
              (g) => g?.subjectCode == s.subjectCode && g?.semesterCode == sem.code,
              orElse: () => null,
            );
        return ClassItem.fromSection(s, grade: g);
      }).toList();
      _loadingClasses = false;
    } catch (e) {
      if (_disposed) return;
      _loadingClasses = false;
      _flagAuth(e);
    }
    notifyListeners();
  }

  /// Pull-to-refresh: reloads the selected semester.
  Future<void> refreshSelected() => selectSemester(_selected!);

  void _flagAuth(Object e) {
    if (e is EmsException && e.statusCode == 401) _authError = e;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
