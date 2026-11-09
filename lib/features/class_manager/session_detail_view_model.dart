import '../../core/network/ems_exception.dart';
import 'package:flutter/foundation.dart';

import '../../data/class_manager_repository.dart';
import '../../models/crm_teacher_class.dart';
import 'class_manager_models.dart';

/// State of one session's detail sheet: the CRM student list of the session
/// plus the EMS status per student. Present / absent counts come from EMS
/// `session-marks`; a session with no EMS marks at all shows its IMS marks
/// (CRM `attendance.status`). The two are never mixed within one session, so
/// students a teacher left blank on EMS stay blank.
class SessionDetailViewModel extends ChangeNotifier {
  final ClassManagerRepository _repository;
  final SessionGroup session;
  final String? sessionKey;

  SessionDetailViewModel(
    this._repository, {
    required this.session,
    required this.sessionKey,
  });

  List<CrmAttendanceRow> _students = [];
  Map<String, String> _emsStatus = {};
  bool _loading = true;
  String? _error;
  bool _disposed = false;

  List<CrmAttendanceRow> get students => _students;
  bool get loading => _loading;
  String? get error => _error;

  /// null = not marked (on EMS, or in IMS when EMS has nothing).
  bool? presentOf(CrmAttendanceRow s) {
    final st = _emsStatus.isEmpty ? s.status : _emsStatus[s.mssv ?? ''];
    if (st == 'present' || st == 'late' || st == 'excused') return true;
    if (st == 'absent') return false;
    return null;
  }

  int get presentCount => _students.where((s) => presentOf(s) == true).length;
  int get absentCount => _students.where((s) => presentOf(s) == false).length;
  int get unmarkedCount => _students.length - presentCount - absentCount;

  Future<void> load() async {
    _loading = true;
    _error = null;
    if (!_disposed) notifyListeners();
    try {
      final key = sessionKey;
      final ems = key == null
          ? <String, String>{}
          : await _repository.sessionMarks(key);
      if (_disposed) return;
      _students = session.students;
      _emsStatus = ems;
      _loading = false;
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      _loading = false;
      _error = crmErrorMessage(e);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
