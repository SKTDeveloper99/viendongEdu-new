import 'package:flutter/foundation.dart';

import '../../data/grades_repository.dart';
import '../../models/crm_student_graduation_summary.dart';
import '../../services/ems_api_service.dart';
import 'grade_item.dart';

/// State of the grades screen: loading / error / data.
///
/// The overview figures come straight from the server's graduation summary
/// (`academic`) — nothing is recomputed here. Only the per-subject list is
/// split (scored / not yet scored) and numbered for retakes.
class GradesViewModel extends ChangeNotifier {
  final GradesRepository _repository;

  GradesViewModel(this._repository);

  CrmAcademicSummary? _stats;
  List<GradeItem> _grades = const []; // có điểm (tongdiem != null)
  List<GradeItem> _chuaHoc = const []; // chưa có điểm (tongdiem == null)
  List<RemainingSubjectItem> _chuaDat = const [];
  bool _loading = true;
  String? _error;
  Object? _authError;
  bool _disposed = false;

  CrmAcademicSummary? get stats => _stats;
  List<GradeItem> get grades => _grades;
  List<GradeItem> get ungraded => _chuaHoc;
  List<RemainingSubjectItem> get remaining => _chuaDat;
  bool get loading => _loading;
  String? get error => _error;

  /// True when the last load failed with HTTP 401. The view reacts by calling
  /// `handleCrmAuthError` with [authError] (session cleared, back to login).
  bool get unauthorized => _authError != null;
  Object? get authError => _authError;

  /// (Re)loads everything. Also the "Thử lại" action.
  Future<void> refresh() async {
    _loading = true;
    _error = null;
    _authError = null;
    notifyListeners();
    try {
      final data = await _repository.load();
      if (_disposed) return;
      final allGrades = withRetakeNumbers(data.grades.grades);
      _grades = allGrades.where((g) => !g.chuaHoc).toList()
        ..sort((a, b) => b.tongdiem.compareTo(a.tongdiem));
      _chuaHoc = allGrades.where((g) => g.chuaHoc).toList();
      _chuaDat = data.summary.remainingSubjects
          .map((r) => RemainingSubjectItem(
                code: r.subjectCode,
                name: r.subjectName,
                credits: r.credits,
                status: switch (r.completionStatus) {
                  'pending' => 1,
                  'failed' => 2,
                  _ => 0,
                },
              ))
          .toList();
      _stats = data.summary.academic;
      _loading = false;
    } catch (e) {
      if (_disposed) return;
      _loading = false;
      _error = e.toString();
      if (e is EmsException && e.statusCode == 401) _authError = e;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
