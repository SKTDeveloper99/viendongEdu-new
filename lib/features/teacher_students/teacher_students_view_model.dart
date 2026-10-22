import 'package:flutter/foundation.dart';

import '../../data/teacher_students_repository.dart';
import '../../models/teacher_care_student.dart';
import '../../services/ems_api_service.dart';
import 'care_read_error.dart';

/// One of the teacher's classes with the students the CRM follows in it.
class CareClass {
  /// Empty for the "other students I look after" group (programme lane).
  final String sectionId;
  final String title;
  final String? code;
  final List<TeacherCareStudent> students;
  const CareClass({
    required this.sectionId,
    required this.title,
    this.code,
    required this.students,
  });

  bool get isOther => sectionId.isEmpty;
}

const otherStudentsTitle = 'Sinh viên khác tôi phụ trách';

/// State of the teacher's student view ("Sinh viên của tôi"): the classes,
/// the students in each, and the two counts at the top. Counts are numbers
/// of students only — never sums of money.
class TeacherStudentsViewModel extends ChangeNotifier {
  final TeacherStudentsRepository _repository;
  TeacherStudentsViewModel(this._repository);

  List<TeacherCareStudent> _students = const [];
  List<CareClass> _classes = const [];
  bool _loading = true;
  String? _error;
  Object? _authError;
  DateTime? _savedAt;
  bool _fresh = true;
  bool _disposed = false;
  bool _refreshing = false;
  bool _accessDenied = false;

  List<TeacherCareStudent> get students => _students;
  List<CareClass> get classes => _classes;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  DateTime? get savedAt => _savedAt;
  String? get error => _error;
  bool get unauthorized => _authError != null;
  Object? get authError => _authError;

  /// Set when the screen shows the last good copy because the refresh failed.
  DateTime? get staleSince => _fresh ? null : _savedAt;

  int get owingCount => _students.where((s) => s.money.owes).length;
  int get attentionCount => _students.where((s) => s.needsAttention).length;

  Future<void> load() async {
    if (_refreshing || _disposed) return;
    _refreshing = true;
    _error = null;
    _authError = null;
    if (_students.isEmpty) _loading = true;
    notifyListeners();
    try {
      final r = await _repository.students();
      if (_disposed) return;
      if (_accessDenied && !r.fresh) {
        throw EmsException('Bạn không có quyền xem danh sách này. Vui lòng liên hệ nhà trường để được hỗ trợ.', statusCode: 403);
      }
      _students = r.data;
      _classes = groupByClass(r.data);
      _savedAt = r.savedAt;
      _fresh = r.fresh;
      _accessDenied = false;
    } catch (e) {
      if (_disposed) return;
      if (careAccessDenied(e)) {
        _accessDenied = true;
        _students = const [];
        _classes = const [];
        _savedAt = null;
        _fresh = true;
        if (e is EmsException && e.statusCode == 401) _authError = e;
      } else if (_savedAt != null) {
        _fresh = false;
      }
      _error = careReadError(e);
    }
    _loading = false;
    _refreshing = false;
    notifyListeners();
  }

  /// Groups students under the classes this teacher teaches. Students in
  /// none of them (programme lane) go to one last group so every counted
  /// student can be opened.
  static List<CareClass> groupByClass(List<TeacherCareStudent> students) {
    final byId = <String, List<TeacherCareStudent>>{};
    final info = <String, CareSection>{};
    final others = <TeacherCareStudent>[];
    for (final s in students) {
      var placed = false;
      for (final id in s.mySectionIds.toSet()) {
        final sec = s.section(id);
        if (sec == null) continue;
        info.putIfAbsent(id, () => sec);
        byId.putIfAbsent(id, () => []).add(s);
        placed = true;
      }
      if (!placed) others.add(s);
    }
    final out = [
      for (final e in byId.entries)
        CareClass(
          sectionId: e.key,
          title:
              info[e.key]!.subjectName ?? info[e.key]!.sectionCode ?? 'Lớp học',
          code: info[e.key]!.sectionCode,
          students: _sorted(e.value),
        ),
    ]..sort((a, b) => a.title.compareTo(b.title));
    if (others.isNotEmpty) {
      out.add(
        CareClass(
          sectionId: '',
          title: otherStudentsTitle,
          students: _sorted(others),
        ),
      );
    }
    return out;
  }

  // Students who owe or need attention first, then by name.
  static List<TeacherCareStudent> _sorted(List<TeacherCareStudent> list) {
    int rank(TeacherCareStudent s) =>
        (s.money.owes || s.needsAttention) ? 0 : 1;
    return [...list]..sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.name.compareTo(b.name);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
