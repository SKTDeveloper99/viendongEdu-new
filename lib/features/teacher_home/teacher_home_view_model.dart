import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/teacher_home_repository.dart';
import '../../models/crm_teacher_profile.dart';
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

  List<Map<String, dynamic>> get todayClasses => _todayClasses;
  bool get scheduleLoading => _scheduleLoading;
  bool get scheduleFailed => _scheduleFailed;

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
          _profile = o.teacher;
          _todayClasses = o.todaySessions.map((s) => s.toJson()).toList();
          _scheduleLoading = false;
          notifyListeners();
        },
      );
      if (_disposed) return;
      _scheduleStaleAt = r.fresh ? null : r.savedAt;
      _profile = r.data.teacher;
      _todayClasses = r.data.todaySessions.map((s) => s.toJson()).toList();
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
