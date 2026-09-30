import 'package:flutter/foundation.dart';

import '../../data/classes_repository.dart';
import '../../services/ems_api_service.dart';
import 'class_models.dart';

/// State of one class's detail page: its EMS attendance sessions.
class ClassDetailViewModel extends ChangeNotifier {
  final ClassesRepository _repository;
  final String sectionCode;

  ClassDetailViewModel(this._repository, {required this.sectionCode});

  List<AttendanceSession> _sessions = [];
  bool _loading = true;
  Object? _authError;
  bool _disposed = false;

  List<AttendanceSession> get sessions => _sessions;
  bool get loading => _loading;
  bool get unauthorized => _authError != null;
  Object? get authError => _authError;

  int get present => _sessions.where((s) => s.hiendien == true).length;
  int get absent => _sessions.where((s) => s.hiendien == false).length;
  int get pending => _sessions.where((s) => s.hiendien == null).length;

  // Điểm danh đọc từ EMS, KHÔNG còn từ IMS. EMS là nguồn chính thức: một buổi
  // chỉ có mặt trong danh sách khi giáo viên đã ghi nhận trên EMS. Lọc trực
  // tiếp theo `section_code` (EmsStudentMark.sectionCode).
  Future<void> load() async {
    _loading = true;
    _authError = null;
    notifyListeners();
    try {
      final marks = await _repository.attendance();
      if (_disposed) return;
      _sessions = marks
          .where((m) => m.sectionCode == sectionCode)
          .map((m) {
            final st = m.status;
            return AttendanceSession(
              // date-only để tránh lệch ngày khi parse mốc UTC nửa đêm
              ngay: (m.sessionDate ?? '').split('T').first,
              hiendien: (st == 'present' || st == 'late')
                  ? true
                  : (st == 'absent' ? false : null),
              baonghi: st == 'excused',
            );
          })
          .toList()
        ..sort((a, b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));
    } catch (e) {
      if (_disposed) return;
      if (e is EmsException && e.statusCode == 401) _authError = e;
    }
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
