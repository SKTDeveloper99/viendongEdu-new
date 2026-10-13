import 'package:flutter/foundation.dart';

import '../../data/teacher_students_repository.dart';
import '../../models/teacher_care_student.dart';
import '../../services/ems_api_service.dart';
import 'care_read_error.dart';

/// Show the list's last good copy while reading; hide it when access is lost.
class StudentDetailViewModel extends ChangeNotifier {
  final TeacherStudentsRepository _repository;
  final String _mssv;
  TeacherCareStudent _student;
  DateTime? _savedAt;
  DateTime? _staleSince;
  String? _error;
  Object? _authError;
  bool _blocked = false;
  bool _refreshing = false;
  bool _disposed = false;

  StudentDetailViewModel(
    this._repository,
    TeacherCareStudent student, {
    DateTime? savedAt,
    DateTime? staleSince,
  }) : _student = student,
       _mssv = student.mssv,
       _savedAt = savedAt ?? staleSince,
       _staleSince = staleSince;

  TeacherCareStudent get student => _student;
  DateTime? get staleSince => _staleSince;
  String? get error => _error;
  Object? get authError => _authError;
  bool get blocked => _blocked;
  bool get refreshing => _refreshing;

  Future<void> refresh() async {
    if (_refreshing || _disposed) return;
    _refreshing = true;
    _error = null;
    _authError = null;
    notifyListeners();
    try {
      final fresh = await _repository.student(_mssv);
      if (_disposed) return;
      if (fresh.mssv != _mssv) throw EmsException('Invalid student');
      // Empty teacher-section permissions are authoritative too.
      _student = fresh;
      _savedAt = DateTime.now();
      _staleSince = null;
      _blocked = false;
    } catch (e) {
      if (_disposed) return;
      _blocked = _blocked || careAccessDenied(e);
      _staleSince = _savedAt;
      _error = careReadError(e);
      if (e is EmsException && e.statusCode == 401) _authError = e;
    }
    _refreshing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
