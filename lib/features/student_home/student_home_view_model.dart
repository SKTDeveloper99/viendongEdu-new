import 'package:flutter/foundation.dart';

import '../../data/student_home_repository.dart';
import '../../models/crm_student_schedule.dart';
import '../../services/ems_api_service.dart';
import 'must_read_gate.dart';

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

  StudentHomeViewModel(
    this._repository, {
    MustReadGate? gate,
    Future<void> Function(Duration)? delay,
    DateTime Function()? now,
  }) : _gate = gate ?? MustReadGate.shared,
       _delay = delay ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  List<CrmScheduleItem> _todayClasses = [];
  DateTime? _scheduleStaleAt;
  bool _scheduleLoading = true;
  bool _scheduleFailed = false;
  int _unreadCount = 0;
  String? _classCode;
  AnnouncementItem? _latestBoardItem;
  int _boardUnread = 0;
  bool _boardFailed = false;
  bool _boardLoading = false;
  bool _mustReadPrompt = false;
  Object? _authError;
  bool _disposed = false;

  List<CrmScheduleItem> get todayClasses => _todayClasses;

  /// Set when the shown schedule is a stored copy (refresh failed).
  DateTime? get scheduleStaleAt => _scheduleStaleAt;
  bool get scheduleLoading => _scheduleLoading;
  bool get scheduleFailed => _scheduleFailed;
  int get unreadCount => _unreadCount;
  AnnouncementItem? get latestBoardItem => _latestBoardItem;
  int get boardUnread => _boardUnread;
  bool get boardFailed => _boardFailed;

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

  /// Screen start-up: schedule first, everything else after a pause.
  void start() {
    loadTodaySchedule();
    _loadSecondary();
  }

  Future<void> _loadSecondary() async {
    await _delay(const Duration(milliseconds: 900));
    if (_disposed) return;
    await _loadProfile();
    if (_disposed) return;
    await _delay(const Duration(milliseconds: 500));
    if (_disposed) return;
    loadUnreadCount();
    loadBoard();
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
        onStored: (items, _) {
          if (_disposed) return;
          _todayClasses = items.where((s) => s.occursOn(today)).toList();
          _scheduleLoading = false;
          notifyListeners();
        },
      );
      final todays = r.data.where((s) => s.occursOn(today)).toList();
      if (_disposed) return;
      _scheduleStaleAt = r.fresh ? null : r.savedAt;
      _todayClasses = todays;
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

  Future<void> _loadProfile() async {
    try {
      final code = await _repository.classCode();
      if (_disposed) return;
      _classCode = code;
      notifyListeners();
    } catch (_) {
      // Header vẫn hiện tên/MSSV từ phiên; chỉ mã lớp trống.
    }
  }

  // Số chưa đọc = Bảng tin CRM. `mustReadPending` gộp vào vì một thông báo
  // bắt buộc đọc mà chưa xác nhận vẫn phải hiện huy hiệu.
  Future<void> loadUnreadCount() async {
    if (!_repository.hasEms) return;
    try {
      final u = await _repository.unreadCount();
      if (_disposed) return;
      _unreadCount = u.unread + u.mustReadPending;
      notifyListeners();
    } catch (_) {}
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
        onStored: (stored, _) {
          if (_disposed) return;
          _latestBoardItem = stored.isEmpty ? null : stored.first;
          notifyListeners();
        },
      );
      final items = r.data;
      final unread = items.where((i) => i.isUnread).length;
      if (_disposed) return;
      _latestBoardItem = items.isEmpty ? null : items.first;
      _boardUnread = unread;
      _boardFailed = false;
      _maybeRequestMustRead(items);
      notifyListeners();
    } catch (_) {
      // A DELIBERATE denial (no EMS account for this student, or a deactivated
      // one) is not a failure to retry — only a real fault gets the retry card.
      if (!_disposed) {
        _latestBoardItem = null;
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
    super.dispose();
  }
}
