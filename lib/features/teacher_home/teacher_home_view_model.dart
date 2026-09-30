import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/teacher_home_repository.dart';
import '../../core/default_semester.dart';
import '../../models/crm_student_schedule.dart' show dayCodeForWeekday;
import '../../models/crm_teacher_class.dart';
import '../../models/crm_teacher_profile.dart';
import '../../services/crm_teacher_api.dart';
import '../../core/schedule/next_up.dart';
import '../../services/ems_api_service.dart';
import '../../services/startup_pace.dart';
import 'next_up.dart' as next_up;

/// State of the teacher home: today's sessions, the "Cơ hữu" profile flag and
/// the unread bell.
///
/// Start-up pacing (unchanged): the first overview load waits
/// `StartupPace.forAccount(id, windowMs: 900)`; the unread count waits
/// 1200 ms + `StartupPace.forAccount(id, windowMs: 1400)`. Both the pacing
/// function and the delay are injectable so tests can zero them.
class TeacherHomeViewModel extends ChangeNotifier {
  final TeacherHomeRepository _repository;
  final Duration Function(String account, {required int windowMs}) _pace;
  final Future<void> Function(Duration) _delay;
  final DateTime Function() _now;
  final Duration? _tickEvery;
  Timer? _ticker;

  /// [tickEvery] is how often the "Tiếp theo" countdown text refreshes
  /// (default 1 minute); pass null to run no timer (tests).
  TeacherHomeViewModel(
    this._repository, {
    Duration Function(String account, {required int windowMs})? pace,
    Future<void> Function(Duration)? delay,
    DateTime Function()? now,
    Duration? tickEvery = const Duration(minutes: 1),
  }) : _pace = pace ?? StartupPace.forAccount,
       _delay = delay ?? Future<void>.delayed,
       _now = now ?? DateTime.now,
       _tickEvery = tickEvery;

  List<Map<String, dynamic>> _todayClasses = [];
  bool _scheduleLoading = true;
  bool _scheduleFailed = false;
  DateTime? _scheduleStaleAt;
  int _unreadCount = 0;
  CrmTeacherProfile? _profile;
  Object? _authError;
  bool _disposed = false;

  // Week strip: weekly pattern of the current semester (from the overview),
  // and the day the list below is showing (null = today).
  List<CrmScheduleSlot> _weeklySlots = [];
  CrmSemester? _currentSemesterRow;
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _dayClasses = [];
  bool _dayLoading = false;
  bool _dayFailed = false;
  int _dayRequest = 0;

  List<Map<String, dynamic>> get todayClasses => _todayClasses;
  bool get scheduleLoading => _scheduleLoading;
  bool get scheduleFailed => _scheduleFailed;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime get today => _dateOnly(_now());

  /// The day whose sessions the list shows.
  DateTime get selectedDay => _selectedDay ?? today;
  bool get viewingToday => _selectedDay == null || _selectedDay == today;

  /// Sessions for [selectedDay]: today's overview list, or the fetched day.
  List<Map<String, dynamic>> get shownClasses =>
      viewingToday ? _todayClasses : _dayClasses;
  bool get shownLoading => viewingToday ? _scheduleLoading : _dayLoading;
  bool get shownFailed => viewingToday ? _scheduleFailed : _dayFailed;

  /// Start times ("HH:MM") of the teaching slots on [day], from the weekly
  /// pattern of the current semester (not dated per session: it cannot know
  /// about cancelled/moved sessions). Max 3 (dots); empty outside the
  /// semester's date range.
  List<String> dotStartsFor(DateTime day) {
    final sem = _currentSemesterRow;
    final d = _dateOnly(day);
    final from = parseSemesterDate(sem?.ngayBatDau);
    final to = parseSemesterDate(sem?.ngayKetThuc);
    if (from != null && d.isBefore(from)) return const [];
    if (to != null && d.isAfter(to)) return const [];
    final code = dayCodeForWeekday(d.weekday);
    final starts =
        _weeklySlots
            .where((s) => s.ngayMa?.trim() == code)
            .map((s) => s.tgBatDau ?? '')
            .toList()
          ..sort();
    return starts.take(3).toList();
  }

  /// Taps on the week strip. Today returns to the overview list; any other
  /// day fetches `GET /me/schedule?date=` (only for that tapped day).
  Future<void> selectDay(DateTime day) async {
    final d = _dateOnly(day);
    if (d == today) {
      _selectedDay = null;
      _dayRequest++;
      _dayLoading = false;
      notifyListeners();
      return;
    }
    _selectedDay = d;
    await _loadDay(d);
  }

  Future<void> reloadSelectedDay() async {
    final d = _selectedDay;
    if (d != null) await _loadDay(d);
  }

  Future<void> _loadDay(DateTime d) async {
    final req = ++_dayRequest;
    _dayLoading = true;
    _dayFailed = false;
    _dayClasses = [];
    notifyListeners();
    try {
      final r = await _repository.scheduleForDate(_iso(d));
      if (_disposed || req != _dayRequest) return;
      _dayClasses = r.map((s) => s.toJson()).toList();
    } catch (e) {
      if (_disposed || req != _dayRequest) return;
      if (e is EmsException && e.statusCode == 401) {
        _authError = e;
      } else {
        _dayFailed = true;
      }
    }
    _dayLoading = false;
    notifyListeners();
  }

  void _applyOverview(CrmTeacherOverview o) {
    _profile = o.teacher;
    _todayClasses = o.todaySessions.map((s) => s.toJson()).toList();
    _weeklySlots = o.semesterSlots;
    CrmSemester? cur;
    for (final s in o.semesters) {
      if (s.ma == o.currentSemester) cur = s;
    }
    _currentSemesterRow = cur;
  }

  /// Set when the shown schedule is a stored copy (refresh failed).
  DateTime? get scheduleStaleAt => _scheduleStaleAt;
  int get unreadCount => _unreadCount;

  /// CRM profile; only needed for the "Cơ hữu" badge (`teachers.type ==
  /// 'gvch'`, see CLAUDE.md "Known state").
  CrmTeacherProfile? get profile => _profile;

  /// Name / code come straight from the login session (no network).
  String get displayName {
    final name = _repository.fullName;
    return (name != null && name.isNotEmpty) ? name : '–';
  }

  String get teacherCode => _repository.teacherCode ?? '–';

  /// True when the overview request failed with HTTP 401; the view reacts by
  /// calling `handleCrmAuthError` with [authError].
  bool get unauthorized => _authError != null;
  Object? get authError => _authError;

  /// The view model's clock (device time unless injected).
  DateTime get now => _now();

  /// "Tiếp theo" card state for [now]; display-only from the loaded sessions.
  NextUp get upNext => next_up.nextUp(_todayClasses, _now());

  /// Starts the once-a-minute countdown refresh (idempotent).
  void startClock() {
    final every = _tickEvery;
    if (every == null || _ticker != null || _disposed) return;
    _ticker = Timer.periodic(every, (_) {
      if (!_disposed) notifyListeners();
    });
  }

  void stopClock() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Screen start-up: overview after its pace, unread count after its own.
  void start() {
    startClock();
    _loadFirstOverview();
    _startUnread();
  }

  Future<void> _startUnread() async {
    final id = _repository.teacherId;
    await _delay(
      const Duration(milliseconds: 1200) + _pace(id, windowMs: 1400),
    );
    if (_disposed) return;
    await loadUnreadCount();
  }

  Future<void> _loadFirstOverview() async {
    final id = _repository.teacherId;
    await _delay(_pace(id, windowMs: 900));
    if (!_disposed) await loadOverview();
  }

  // Số chưa đọc = CRM `/teacher/notifications/unread-count` (thay
  // backend Vercel “noti-backend-eight” (đã gỡ), bot A5, 2026-09-25).
  Future<void> loadUnreadCount() async {
    if (!_repository.hasEms) return;
    try {
      final count = await _repository.unreadCount();
      if (_disposed) return;
      _unreadCount = count;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadOverview() async {
    if (!_disposed) {
      _scheduleLoading = true;
      notifyListeners();
    }
    try {
      // Một lời gọi CRM duy nhất: hồ sơ + lịch dạy hôm nay + tóm tắt học kỳ
      // (`GET /api/teacher/me/overview`) — thay cho IMS `giangvien/tkbtheongay`.
      final r = await _repository.overview(
        onStored: (o, _) {
          if (_disposed) return;
          _applyOverview(o);
          _scheduleLoading = false;
          notifyListeners();
        },
      );
      if (_disposed) return;
      _scheduleStaleAt = r.fresh ? null : r.savedAt;
      _applyOverview(r.data);
      _scheduleFailed = false;
      _scheduleLoading = false;
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      if (e is EmsException && e.statusCode == 401) {
        _authError = e;
        notifyListeners();
        return;
      }
      _todayClasses = [];
      _scheduleFailed = true;
      _scheduleLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() => _repository.clearSession();

  @override
  void dispose() {
    _disposed = true;
    stopClock();
    super.dispose();
  }
}
