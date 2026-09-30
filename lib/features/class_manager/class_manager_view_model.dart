import 'package:flutter/foundation.dart';

import '../../data/class_manager_repository.dart';
import '../../models/crm_teacher_class.dart';
import '../../services/ems_api_service.dart';
import 'class_manager_models.dart';

/// State of the class list: semesters (newest first), the classes of the
/// selected semester, the stored-copy note and the `lmhma -> lmhid` map the
/// detail sheets need for EMS session keys.
class ClassManagerViewModel extends ChangeNotifier {
  final ClassManagerRepository repository;

  ClassManagerViewModel(this.repository);

  List<ClassSemester> _semesters = [];
  ClassSemester? _selected;
  List<CrmTeacherClass> _classes = [];
  DateTime? _staleAt;

  /// `lmhma` (mã lớp môn học, = `sectionCode`) -> `lmhid`. Comes from
  /// `GET /me/schedule/semester` (the only CRM endpoint still returning it),
  /// fetched together with the classes.
  Map<String, String> _lmhIdByCode = {};

  bool _loadingSemesters = true;
  bool _loadingClasses = false;
  String? _error;
  Object? _authError;
  bool _disposed = false;

  List<ClassSemester> get semesters => _semesters;
  ClassSemester? get selected => _selected;
  List<CrmTeacherClass> get classes => _classes;

  /// Set when the shown classes are a stored copy (refresh failed).
  DateTime? get staleAt => _staleAt;
  bool get loadingSemesters => _loadingSemesters;
  bool get loadingClasses => _loadingClasses;
  String? get error => _error;

  /// True when a request failed with HTTP 401; the view reacts by calling
  /// `handleCrmAuthError` with [authError].
  bool get unauthorized => _authError != null;
  Object? get authError => _authError;

  String? lmhIdOf(CrmTeacherClass lop) => _lmhIdByCode[lop.sectionCode];

  static bool _is401(Object e) => e is EmsException && e.statusCode == 401;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> fetchSemesters() async {
    _loadingSemesters = true;
    _error = null;
    _authError = null;
    _notify();
    try {
      final data = await repository.semesters();
      final sems =
          data
              .map((e) => ClassSemester(id: e.id, ma: e.ma, ten: e.ten))
              .toList()
            ..sort((a, b) => b.id.compareTo(a.id));
      if (_disposed) return;
      _semesters = sems;
      _loadingSemesters = false;
      _notify();
      if (sems.isNotEmpty) await selectSemester(sems.first);
    } catch (e) {
      if (_disposed) return;
      if (_is401(e)) {
        _authError = e;
        _notify();
        return;
      }
      _loadingSemesters = false;
      _error = e.toString();
      _notify();
    }
  }

  Future<void> selectSemester(ClassSemester sem) async {
    _selected = sem;
    _loadingClasses = true;
    _error = null;
    _authError = null;
    _notify();
    try {
      final results = await Future.wait([
        repository.classes(
          semester: sem.ma,
          onStored: (c, _) {
            if (_disposed || _selected != sem) return;
            _classes = c;
            _loadingClasses = false;
            _notify();
          },
        ),
        repository.schedule(sem.ma),
      ]);
      if (_disposed) return;
      final cached = results[0] as CachedTeacherClasses;
      _staleAt = cached.fresh ? null : cached.savedAt;
      final slots = results[1] as List<CrmScheduleSlot>;
      _classes = cached.data;
      _lmhIdByCode = {for (final s in slots) s.lmhMa: s.lmhId};
      _loadingClasses = false;
      _notify();
    } catch (e) {
      if (_disposed) return;
      if (_is401(e)) {
        _authError = e;
        _notify();
        return;
      }
      _loadingClasses = false;
      _error = e.toString();
      _notify();
    }
  }

  void retry() {
    if (_semesters.isEmpty) {
      fetchSemesters();
    } else if (_selected != null) {
      selectSemester(_selected!);
    } else {
      fetchSemesters();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
