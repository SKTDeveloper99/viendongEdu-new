import 'package:flutter/foundation.dart';

import '../../data/teacher_attendance_repository.dart';
import '../../services/ems_api_service.dart';

/// Today's EMS sessions of the signed-in teacher.
class SessionListViewModel extends ChangeNotifier {
  SessionListViewModel(this.repository);

  final TeacherAttendanceRepository repository;

  bool _loading = true;
  String? _error;
  List<EmsSession> _sessions = const [];
  bool _disposed = false;

  bool get loading => _loading;
  String? get error => _error;
  List<EmsSession> get sessions => _sessions;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final s = await repository.mySessions();
      if (_disposed) return;
      _sessions = s;
      _loading = false;
      _notify();
    } on EmsException catch (e) {
      if (_disposed) return;
      _sessions = const [];
      _error = 'Không có kết nối. Kiểm tra mạng và thử lại. ${e.message}';
      _loading = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
