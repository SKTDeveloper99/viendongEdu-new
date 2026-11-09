import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/student_home_repository.dart';
import '../../models/crm_student_schedule.dart';
import '../../models/crm_student_exams.dart';
import '../../services/ems_api_service.dart';
import '../../core/schedule/next_up.dart';
import 'must_read_gate.dart';
import 'next_up.dart' as next_up;

/// State of the student home: today's classes, the header identity, the unread
/// bell and the latest board card.
///
/// Load order (unchanged): today's schedule immediately; then after 900 ms the
/// profile, and 500 ms later the unread count and the board. The delays are
/// injectable so tests can zero them.
class StudentHomeViewModel extends ChangeNotifier {
  final StudentHomeRepository _repository;
  final MustReadGate _gate;
  final Future<void> Function(Duration) _delay;
  final DateTime Function() _now;
  final Duration? _tickEvery;
  Timer? _ticker;

  /// [tickEvery] is how often the "Tiếp theo" countdown text refreshes
  /// (default 1 minute); pass null to run no timer (tests).
  StudentHomeViewModel(
    this._repository, {
    MustReadGate? gate,
    Future<void> Function(Duration)? delay,
    DateTime Function()? now,
    Duration? tickEvery = const Duration(minutes: 1),
  }) : _tickEvery = tickEvery,
       _gate = gate ?? MustReadGate.shared,
       _delay = delay ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  List<CrmStudentExam> _exams = [];
  bool examsLoading = true;
  bool examsFailed = false;
  DateTime? examsStaleAt;
  List<CrmStudentExam> get upcomingExams => next_up.upcomingExams(_exams, now);
  bool get hasExamToday => upcomingExams.any((e) => e.occursOn(now));

  Future<void> loadExams() async {
    if (_disposed) return;
    examsLoading = true;
    notifyListeners();
    try {
      final r = await _repository.exams();
      if (_disposed) return;
      _exams = r.data.exams;
      examsStaleAt = r.fresh ? null : r.savedAt;
      examsFailed = false;
    } catch (e) {
      if (_disposed) return;
      examsFailed = true;
      if (e is EmsException && e.statusCode == 401) _authError = e;
    } finally {
      if (!_disposed) {
        examsLoading = false;
        notifyListeners();
      }
    }
  }

  List<CrmScheduleItem> _todayClasses = [];
  DateTime? _scheduleStaleAt;
  DateTime? _boardStaleAt;
  bool _scheduleLoading = true;
  bool _scheduleFailed = false;
  bool _scheduleDenied = false;
  int _unreadCount = 0;
  String? _classCode;
  AnnouncementItem? _latestBoardItem;
  int _boardUnread = 0;
  bool _boardFailed = false;
  bool _profileFailed = false;
  bool _unreadFailed = false;
  bool _boardLoading = false;
  bool _mustReadPrompt = false;
  Object? _authError;
  bool _disposed = false;

  List<CrmScheduleItem> get todayClasses => _todayClasses;

  int _unscheduledSubjects = 0;

  /// Subjects this student studies whose timetable is not published yet
  /// (`chua_co_lich`); 0 when there are none or the schedule failed.
  int get unscheduledSubjects => _unscheduledSubjects;

  static int _countSubjects(List<CrmUnscheduledSection> sections) => {
    for (final s in sections)
      s.subjectCode.isNotEmpty
          ? 'code:${s.subjectCode}'
          : s.subjectName.isNotEmpty
          ? 'name:${s.subjectName}'
          : 'section:${s.sectionCode}',
  }.length;

  /// Set when the shown schedule is a stored copy (refresh failed).
  DateTime? get scheduleStaleAt => _scheduleStaleAt;
  bool get scheduleLoading => _scheduleLoading;
  bool get scheduleFailed => _scheduleFailed;
  bool get scheduleDenied => _scheduleDenied;
  int get unreadCount => _unreadCount;
  AnnouncementItem? get latestBoardItem => _latestBoardItem;
  int get boardUnread => _boardUnread;
  bool get boardFailed => _boardFailed;
  bool get secondaryFailed => _profileFailed || _unreadFailed;
  DateTime? get boardStaleAt => _boardStaleAt;

  String get name => _repository.fullName ?? '–';
  String get mssv => _repository.mssv ?? '–';
  String get classCode => _classCode ?? '–';

  /// True when the schedule request failed with HTTP 401; the view reacts by
  /// calling `handleCrmAuthError` with [authError].
  bool get unauthorized => _authError != null;
  Object? get authError => _authError;

  /// True once when a must-read announcement should be pushed; reading it via
  /// [takeMustReadPrompt] clears it.
  bool get mustReadPrompt => _mustReadPrompt;
  bool takeMustReadPrompt() {
    final v = _mustReadPrompt;
    _mustReadPrompt = false;
    return v;
  }

  /// The view model's clock (device time unless injected).
  DateTime get now => _now();

  /// "Tiếp theo" card state for [now]; display-only from the loaded schedule.
  NextUp get upNext => next_up.nextUp(_todayClasses, _now(), exams: _exams);

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

  /// Screen start-up: schedule first, then the rest together after a short
  /// stagger. These reads cost 3–15 ms on the server (measured 2026-10-16),
  /// so the old 900 ms + 500 ms pacing only made the header and board late.
  void start() {
    startClock();
    loadTodaySchedule();
    loadExams();
    _loadSecondary();
  }

  Future<void> _loadSecondary() async {
    await _delay(const Duration(milliseconds: 200));
    if (_disposed) return;
    loadUnreadCount();
    loadBoard();
    await _loadProfile();
  }

  // Lịch học hôm nay = mọi buổi trong /me/schedule (mọi học kỳ, server không
  // lọc theo ngày) mà rơi đúng hôm nay theo thứ + khoảng ngày học phần — xem
  // CrmScheduleItem.occursOn và ghi chú "weeks_pattern" trong
  // lib/models/crm_student_schedule.dart.
  Future<void> loadTodaySchedule() async {
    if (!_disposed) {
      _scheduleLoading = true;
      notifyListeners();
    }
    try {
      final today = _now();
      final r = await _repository.schedule(
        onStored: (view, at) {
          if (_disposed) return;
          _scheduleStaleAt = at;
          _todayClasses = view.schedule
              .where((s) => s.occursOn(today))
              .toList();
          _unscheduledSubjects = _countSubjects(view.chuaCoLich);
          _scheduleLoading = false;
          notifyListeners();
        },
      );
      final todays = r.data.schedule.where((s) => s.occursOn(today)).toList();
      if (_disposed) return;
      _scheduleStaleAt = r.fresh ? null : r.savedAt;
      _todayClasses = todays;
      _unscheduledSubjects = _countSubjects(r.data.chuaCoLich);
      _scheduleFailed = false;
      _scheduleDenied = false;
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
      _unscheduledSubjects = 0;
      _scheduleFailed = true;
      _scheduleDenied = e is EmsException && e.statusCode == 403;
      _scheduleLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final code = await _repository.classCode();
      if (_disposed) return;
      _classCode = code;
      _profileFailed = false;
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      if (e is EmsException && e.statusCode == 401) _authError = e;
      _profileFailed = true;
      notifyListeners();
    }
  }

  /// Normal home refresh also re-reads owner corrections and the server gate.
  Future<void> refresh() async {
    await Future.wait([
      loadTodaySchedule(),
      loadExams(),
      _loadProfile(),
      loadUnreadCount(),
      loadBoard(),
    ]);
  }

  // Số chưa đọc = Bảng tin CRM. `mustReadPending` gộp vào vì một thông báo
  // bắt buộc đọc mà chưa xác nhận vẫn phải hiện huy hiệu.
  Future<void> loadUnreadCount() async {
    if (!_repository.hasEms) return;
    try {
      final u = await _repository.unreadCount();
      if (_disposed) return;
      _unreadCount = u.unread + u.mustReadPending;
      _unreadFailed = false;
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      if (e is EmsException && e.statusCode == 401) _authError = e;
      _unreadFailed = true;
      notifyListeners();
    }
  }

  /// Thẻ mới nhất + số chưa đọc của Bảng tin.
  ///
  /// Nuốt mọi lỗi: một EMS chết KHÔNG được phép làm hỏng trang chủ. Thẻ chỉ
  /// đơn giản là không hiện, và [boardFailed] cho phép hiện trạng thái thử lại.
  Future<void> loadBoard() async {
    if (_boardLoading) return;
    _boardLoading = true;
    try {
      final r = await _repository.board(
        onStored: (stored, at) {
          if (_disposed) return;
          _boardStaleAt = at;
          _latestBoardItem = stored.isEmpty ? null : stored.first;
          notifyListeners();
        },
      );
      final items = r.data;
      _boardStaleAt = r.fresh ? null : r.savedAt;
      final unread = items.where((i) => i.isUnread).length;
      if (_disposed) return;
      _latestBoardItem = items.isEmpty ? null : items.first;
      _boardUnread = unread;
      _boardFailed = false;
      _maybeRequestMustRead(items);
      notifyListeners();
    } catch (e) {
      if (e is EmsException && e.statusCode == 401) _authError = e;
      // A DELIBERATE denial (no EMS account for this student, or a deactivated
      // one) is not a failure to retry — only a real fault gets the retry card.
      if (!_disposed) {
        _latestBoardItem = null;
        _boardStaleAt = null;
        _boardUnread = 0;
        _boardFailed = !_repository.emsDenied;
        notifyListeners();
      }
    } finally {
      _boardLoading = false;
    }
  }

  /// Nhiều nhất MỘT lần mỗi phiên: nhắc thông báo bắt buộc đọc chưa xác nhận.
  void _maybeRequestMustRead(List<AnnouncementItem> items) {
    if (_gate.shown) return;
    if (!items.any((i) => i.needsAcknowledgement)) return;
    if (_gate.tryShow()) _mustReadPrompt = true;
  }

  /// Clears the session and re-arms the once-per-session prompt for the next
  /// student who logs in on this process.
  Future<void> logout() async {
    _gate.reset();
    await _repository.clearSession();
  }

  @override
  void dispose() {
    _disposed = true;
    stopClock();
    super.dispose();
  }
}
