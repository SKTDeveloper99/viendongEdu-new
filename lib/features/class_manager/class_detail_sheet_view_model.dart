import 'package:flutter/foundation.dart';

import '../../data/class_manager_repository.dart';
import '../../models/crm_teacher_class.dart';
import '../../services/ems_api_service.dart';
import 'class_manager_models.dart';

/// State of one class's detail sheet: student list, CRM attendance rows
/// grouped by session / by student, and the EMS counts per session.
///
/// Attendance numbers are display-only: the CRM `attendance` rows only list
/// the sessions and their students; EMS `session-marks` is the source of the
/// real present count (CLAUDE.md "EMS write path").
class ClassDetailSheetViewModel extends ChangeNotifier {
  final ClassManagerRepository _repository;
  final CrmTeacherClass lop;
  final String? lmhId;
  final DateTime Function() _now;

  ClassDetailSheetViewModel(
    this._repository, {
    required this.lop,
    required this.lmhId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  List<CrmClassStudent> _students = [];
  bool _loadingStudents = false;
  String? _studentsError;

  List<CrmAttendanceRow> _attendanceRows = [];
  List<SessionGroup> _sessions = [];
  List<StudentAttendanceTotal> _totals = [];
  bool _loadingAttendance = false;
  String? _attendanceError;
  int _subTab = 0; // 0 = buổi học, 1 = tổng hợp

  /// session_key -> (present, total EMS rows).
  final Map<String, EmsSessionCount> _emsCounts = {};

  Object? _authError;
  bool _disposed = false;

  List<CrmClassStudent> get students => _students;
  bool get loadingStudents => _loadingStudents;
  String? get studentsError => _studentsError;

  List<SessionGroup> get sessions => _sessions;
  List<StudentAttendanceTotal> get totals => _totals;
  bool get loadingAttendance => _loadingAttendance;
  String? get attendanceError => _attendanceError;
  int get subTab => _subTab;

  bool get unauthorized => _authError != null;
  Object? get authError => _authError;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Lazy loading when the tab is first opened (1 = students, 2 = attendance).
  void onTabSelected(int index) {
    if (index == 1 &&
        _students.isEmpty &&
        !_loadingStudents &&
        _studentsError == null) {
      loadStudents();
    }
    if (index == 2 &&
        _attendanceRows.isEmpty &&
        !_loadingAttendance &&
        _attendanceError == null) {
      loadAttendance();
    }
  }

  void setSubTab(int value) {
    _subTab = value;
    _notify();
  }

  Future<void> loadStudents() async {
    _loadingStudents = true;
    _studentsError = null;
    _notify();
    try {
      final data = await _repository.students(lop.sectionId);
      if (_disposed) return;
      _students = data;
      _loadingStudents = false;
      _notify();
    } catch (e) {
      if (_disposed) return;
      if (e is EmsException && e.statusCode == 401) {
        _authError = e;
        _notify();
        return;
      }
      _loadingStudents = false;
      _studentsError = e.toString();
      _notify();
    }
  }

  Future<void> loadAttendance() async {
    _loadingAttendance = true;
    _attendanceError = null;
    _notify();
    try {
      final rows = await _repository.attendance(lop.sectionId);
      if (_disposed) return;
      _attendanceRows = rows;
      _sessions = groupBySession(rows);
      _totals = aggregateByStudent(rows);
      _loadingAttendance = false;
      _notify();
      await _loadEmsCounts();
    } catch (e) {
      if (_disposed) return;
      if (e is EmsException && e.statusCode == 401) {
        _authError = e;
        _notify();
        return;
      }
      _loadingAttendance = false;
      _attendanceError = e.toString();
      _notify();
    }
  }

  static List<SessionGroup> groupBySession(List<CrmAttendanceRow> rows) {
    final Map<String, SessionGroup> byId = {};
    for (final r in rows) {
      final b = byId.putIfAbsent(
        r.sessionId,
        () => SessionGroup(
          sessionId: r.sessionId,
          date: r.date,
          startTime: r.startTime,
          endTime: r.endTime,
          room: r.room,
        ),
      );
      if (r.mssv != null && r.mssv!.isNotEmpty) {
        b.students.add(r);
      }
    }
    final list = byId.values.toList()
      ..sort((a, b) => (a.date ?? '').compareTo(b.date ?? ''));
    return list;
  }

  static List<StudentAttendanceTotal> aggregateByStudent(
    List<CrmAttendanceRow> rows,
  ) {
    final Map<String, StudentAttendanceTotal> byMssv = {};
    for (final r in rows) {
      final mssv = r.mssv;
      if (mssv == null || mssv.isEmpty) continue;
      final agg = byMssv.putIfAbsent(
        mssv,
        () => StudentAttendanceTotal(mssv: mssv, fullName: r.fullName ?? ''),
      );
      agg.total++;
      if (r.status == 'present') agg.present++;
    }
    final list = byMssv.values.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    return list;
  }

  /// EMS `session_key` of [b]; null when the class has no `lmhid` or the
  /// session has no date.
  String? sessionKeyOf(SessionGroup b) {
    final id = lmhId;
    if (id == null || id.isEmpty || b.date == null) return null;
    final ngay = b.date!.length >= 10 ? b.date!.substring(0, 10) : b.date!;
    return _repository.sessionKey(
      lmhId: id,
      date: ngay,
      startTime: b.startTime ?? '',
    );
  }

  /// Only sessions already due are asked (future ones cannot have marks), and
  /// only when the `lmhid` is known.
  Future<void> _loadEmsCounts() async {
    if (lmhId == null) return;
    final today = _todayHcm();
    final due = _sessions.where((b) {
      final ngay = b.date ?? '';
      return ngay.length >= 10 && ngay.substring(0, 10).compareTo(today) <= 0;
    }).toList();
    await Future.wait(
      due.map((b) async {
        final key = sessionKeyOf(b);
        if (key == null) return;
        try {
          final marks = await _repository.sessionMarks(key);
          final present = marks.values
              .where((v) => v == 'present' || v == 'late' || v == 'excused')
              .length;
          _emsCounts[key] = EmsSessionCount(
            present: present,
            total: marks.length,
          );
        } catch (_) {
          // Offline / EMS error: keep as is, the row says "chưa có trên EMS".
        }
      }),
    );
    _notify();
  }

  String _todayHcm() {
    final d = _now().toUtc().add(const Duration(hours: 7));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// What the "Buổi học" row of [b] shows.
  SessionRowSummary summaryOf(SessionGroup b) {
    final siso = lop.enrolledStudents;
    final key = sessionKeyOf(b);
    final ems = key == null ? null : _emsCounts[key];
    final marked = ems != null && ems.total > 0;
    final crmPresent = b.students.where((s) => s.status == 'present').length;
    final hiendien = marked ? ems.present : crmPresent;
    final pct = siso > 0 ? hiendien / siso : 0.0;
    final countText = marked
        ? '$hiendien / $siso có mặt (EMS)'
        : crmPresent > 0
        ? '$crmPresent / $siso có mặt trên CRM — chưa xác nhận trên EMS'
        : '0 / $siso — chưa điểm danh';
    return SessionRowSummary(marked: marked, pct: pct, countText: countText);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
