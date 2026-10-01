import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/teacher_attendance_repository.dart';
import '../../services/ems_api_service.dart';
import 'attendance_format.dart';
import 'attendance_outbox.dart';
import 'attendance_sender.dart' hide isClientRefusal;
import 'attendance_sender.dart' as snd show isClientRefusal;
import 'draft_merge.dart';

/// What the save flow asks of the view. The view model never shows a dialog
/// or a snackbar itself; it awaits these.
class RosterPrompts {
  const RosterPrompts({
    required this.confirmUnmarked,
    required this.askReasons,
    required this.toast,
  });

  /// Lists the undecided students; true = save the [chosen] marks anyway.
  final Future<bool> Function(List<EmsRosterStudent> undecided, int chosen)
  confirmUnmarked;

  /// Reason per punched student, or null when the dialog was dismissed.
  final Future<Map<String, String>?> Function(
    List<EmsPunchedStudent> people,
    Map<String, String> initial,
    String Function(String mssv) nameOf,
  )
  askReasons;

  final void Function(String message, {bool good}) toast;
}

/// Roster of one session: the teacher's marks and notes, the offline draft
/// (written before every send) and the save state machine.
class RosterViewModel extends ChangeNotifier {
  RosterViewModel(this.repository, this.session, {AttendanceOutbox? outbox})
    : _outbox = outbox {
    _finishedSub = outbox?.finished.listen((key) {
      // The background drainer settled this session: show the new state.
      if (key == draftKey && !_saving && !_loading && !_disposed) {
        unawaited(load());
      }
    });
  }

  final TeacherAttendanceRepository repository;
  final EmsSession session;
  final AttendanceOutbox? _outbox;
  StreamSubscription<String>? _finishedSub;

  bool _loading = true;
  bool _saving = false;
  bool _queued = false;
  bool _needsReview = false;
  String? _error;
  List<EmsRosterStudent> _students = const [];
  DateTime? _scanSyncedAt;
  bool _disposed = false;

  /// mssv -> 'present' | 'absent'. Vắng mặt trong map = CHƯA ĐIỂM DANH.
  final Map<String, String> _marks = {};
  final Map<String, String> _notes = {};

  /// 18/09 (Dũng): giáo viên điểm danh tay muốn dò tên theo A–Z. Mặc định
  /// giữ thứ tự danh sách lớp của IMS; bật nút trên thanh tiêu đề để xếp
  /// theo TÊN (chữ cuối) rồi họ, bỏ dấu khi so sánh.
  bool _sortAz = false;

  /// Danh sách học viên đã quẹt cổng mà bị ghi vắng, máy chủ đang chờ lý do.
  /// Khi khác null: hàng đợi tắt, thanh dưới nhắc; bấm Lưu để nêu lý do.
  List<EmsPunchedStudent>? _needsReason;

  bool get loading => _loading;
  bool get saving => _saving;
  bool get queued => _queued;
  bool get needsReview => _needsReview;
  String? get error => _error;
  List<EmsRosterStudent> get students => _students;
  DateTime? get scanSyncedAt => _scanSyncedAt;
  bool get sortAz => _sortAz;
  List<EmsPunchedStudent>? get needsReason => _needsReason;
  Map<String, String> get marks => Map.unmodifiable(_marks);
  String? markOf(String mssv) => _marks[mssv];

  List<EmsRosterStudent> get visibleStudents {
    if (!_sortAz) return _students;
    final sorted = List<EmsRosterStudent>.of(_students);
    sorted.sort((a, b) {
      final c = givenNameSortKey(
        a.fullName,
      ).compareTo(givenNameSortKey(b.fullName));
      return c != 0 ? c : a.mssv.compareTo(b.mssv);
    });
    return sorted;
  }

  int get presentCount => _marks.values.where((v) => v == 'present').length;
  int get absentCount => _marks.values.where((v) => v == 'absent').length;
  int get lateCount => _marks.values.where((v) => v == 'late').length;
  int get excusedCount => _marks.values.where((v) => v == 'excused').length;
  int get unmarkedCount => _students.length - _marks.length;
  int get scannedCount => _students.where((s) => s.scanned).length;
  int get unscannedCount => _students.length - scannedCount;
  int get scansPending =>
      _students.where((s) => s.scanned && !_marks.containsKey(s.mssv)).length;
  bool get allPresent =>
      _students.isNotEmpty &&
      _students.every((s) => _marks[s.mssv] == 'present');

  String get draftKey => session.sessionKey.isNotEmpty
      ? session.sessionKey
      : '${session.sectionId}:${session.startTime ?? 'na'}:'
            '${session.sessionDate}';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void toggleSort() {
    _sortAz = !_sortAz;
    _notify();
  }

  /// The draft is read BEFORE the roster request, then merged with it.
  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    final draft = await repository.loadDraft(draftKey);
    try {
      final r = await repository.roster(session);
      if (_disposed) return;
      if (r.sessionKey.trim().isEmpty || r.sessionKey != session.sessionKey) {
        throw EmsException(
          'EMS trả về một buổi học khác. Chưa mở danh sách; vui lòng tải lại lịch.',
        );
      }
      if (session.rosterSize > 0 && r.students.length != session.rosterSize) {
        throw EmsException(
          'Sĩ số EMS không khớp buổi đã chọn '
          '(${r.students.length}/${session.rosterSize}). '
          'Chưa mở danh sách; vui lòng tải lại lịch.',
        );
      }
      final seenMssv = <String>{};
      if (r.students.any((student) {
        final mssv = student.mssv.trim();
        final name = student.fullName.trim();
        return mssv.isEmpty || name.isEmpty || !seenMssv.add(mssv);
      })) {
        throw EmsException(
          'Danh sách EMS thiếu tên/mã học viên hoặc có mã bị trùng. '
          'Chưa mở danh sách; vui lòng tải lại lịch.',
        );
      }
      final merged = mergeDraftWithRoster(draft, r.students);
      _students = r.students;
      _scanSyncedAt = r.scanSyncedAt;
      _marks
        ..clear()
        ..addAll(merged.marks);
      _notes
        ..clear()
        ..addAll(merged.notes);
      _needsReview = merged.needsReview;
      _queued = merged.queued;
      _loading = false;
      _notify();
      final keep = merged.draftToSave;
      if (keep != null) {
        await repository.saveDraft(
          draftKey,
          keep.marks,
          keep.notes,
          queued: keep.queued,
          students: keep.students,
          session: session,
        );
      } else {
        await _persistDraft();
      }
    } on EmsException catch (e) {
      if (_disposed) return;
      _students = const [];
      _error = 'Không có kết nối. Kiểm tra mạng và thử lại. ${e.message}';
      _loading = false;
      _notify();
    }
  }

  Future<void> _persistDraft() => repository
      .saveDraft(
        draftKey,
        _marks,
        _notes,
        queued: _queued,
        students: _students,
        session: session,
      )
      .whenComplete(() => _outbox?.refreshCount());

  void select(String mssv, String? status) {
    if (status == null) {
      _marks.remove(mssv);
    } else {
      _marks[mssv] = status;
    }
    _notify();
    unawaited(_persistDraft());
  }

  void markScannedPresent() {
    for (final s in _students) {
      if (s.scanned && !_marks.containsKey(s.mssv)) {
        _marks[s.mssv] = 'present';
      }
    }
    _notify();
    unawaited(_persistDraft());
  }

  void markAllPresent() {
    for (final s in _students) {
      _marks[s.mssv] = 'present';
    }
    _notify();
    unawaited(_persistDraft());
  }

  /// Bấm nhầm "Tất cả có mặt" (Dũng, 18/09): quay về đúng chỗ trước khi bấm —
  /// ai máy chủ đã lưu thì giữ dấu đã lưu, ai đã quẹt cổng thì có mặt, còn
  /// lại CHƯA ĐIỂM DANH. Không bao giờ xoá dấu đã lưu chỉ vì bỏ chọn.
  void resetToScanned() {
    _marks.clear();
    for (final s in _students) {
      if (s.status != null) {
        _marks[s.mssv] = s.status!;
      } else if (s.scanned) {
        _marks[s.mssv] = 'present';
      }
    }
    _notify();
    unawaited(_persistDraft());
  }

  // Học viên đã có điểm danh trên máy chủ nhưng nay bị BỎ CHỌN. Gửi kèm để máy
  // chủ xoá — nếu chỉ bỏ khỏi danh sách gửi, dấu điểm danh cũ vẫn còn (đúng là
  // lỗi "chọn tất cả -> bỏ vài người -> lưu lại mà vẫn có mặt").
  List<String> get _toRemove => marksToRemove(_students, _marks);

  Future<void> save(RosterPrompts ui) async {
    if (_marks.isEmpty && _toRemove.isEmpty) {
      ui.toast('Chưa chọn gì để lưu.');
      return;
    }
    // 17/09 (Huy, lớp 43461): 12 học viên chưa chạm tới, bấm Lưu vẫn xanh.
    // Máy chủ KHÔNG ghi vắng người chưa điểm danh — nhưng thầy/cô tưởng đã
    // xong. Hỏi rõ trước khi lưu thiếu; không bao giờ tự ghi vắng thay.
    if (unmarkedCount > 0) {
      final undecided = _students
          .where((s) => !_marks.containsKey(s.mssv))
          .toList();
      final go = await ui.confirmUnmarked(undecided, _marks.length);
      if (!go) return;
    }
    if (!AttendanceSendLock.tryAcquire(draftKey)) {
      ui.toast('Đang tự động gửi buổi này, vui lòng đợi giây lát.');
      return;
    }
    _saving = true;
    _queued = true;
    _needsReview = false;
    _needsReason = null;
    _notify();
    try {
      await _persistDraft();
      await _sendMarks(ui);
    } on EmsPunchConflict catch (c) {
      // Không phải lỗi — máy đang hỏi. Hỏi lý do rồi gửi lại đúng một lần.
      final ok = await _askReasons(ui, c.students);
      if (ok) {
        try {
          await _sendMarks(ui);
        } on EmsPunchConflict catch (c2) {
          _holdForReason(ui, c2);
        } on EmsException catch (e) {
          ui.toast(e.message);
        }
      } else {
        // Thầy/cô đóng hộp thoại: KHÔNG được để hàng đợi tự gửi lại y hệt
        // mỗi 20 giây (17/09, Hậu: bốn lần 422 trong 30 giây).
        _holdForReason(ui, c);
      }
    } on EmsException catch (e) {
      if (snd.isClientRefusal(e)) {
        // 4xx là câu trả lời dứt khoát của máy chủ; gửi lại y hệt vô ích.
        _queued = false;
        _notify();
        await _persistDraft();
        ui.toast('Máy chủ từ chối: ${e.message}');
      } else {
        ui.toast(
          'CHƯA GỬI. Đã giữ trên máy, sẽ tự gửi khi có mạng. ${e.message}',
        );
      }
    } finally {
      AttendanceSendLock.release(draftKey);
      _saving = false;
      _notify();
    }
  }

  void _holdForReason(RosterPrompts ui, EmsPunchConflict c) {
    if (_disposed) return;
    _queued = false;
    _needsReason = c.students;
    _notify();
    unawaited(_persistDraft());
    ui.toast(
      'CHƯA LƯU — ${c.students.length} học viên đã quẹt cổng nhưng ghi vắng. '
      'Bấm Lưu để nêu lý do.',
    );
  }

  static bool isClientRefusal(EmsException e) => snd.isClientRefusal(e);

  Future<void> _sendMarks(RosterPrompts ui) async {
    // A 200 response is not enough: sendAndVerify reads the session back and
    // proves every row survived before we tell the teacher it is stored.
    final sent = await sendAndVerify(
      repository,
      session,
      _marks,
      _notes,
      _students,
    );
    final res = sent.result;
    final confirmed = sent.confirmed;
    await repository.clearDraft(draftKey);
    unawaited(_outbox?.refreshCount());
    if (_disposed) return;
    _students = confirmed.students;
    _queued = false;
    _needsReason = null;
    _notify();
    final late = res.late ? ' (ghi muộn)' : '';
    final over = res.overriddenPunches.isEmpty
        ? ''
        : ' • ${res.overriddenPunches.length} ca ghi vắng dù đã quẹt cổng';
    ui.toast('Đã lưu ${res.saved} dòng$late$over', good: true);
  }

  /// Bắt buộc nêu lý do cho từng học viên đã quẹt cổng mà bị ghi vắng.
  /// Trả về true nếu đã điền đủ.
  Future<bool> _askReasons(
    RosterPrompts ui,
    List<EmsPunchedStudent> people,
  ) async {
    final notes = await ui.askReasons(people, _notes, nameOf);
    if (notes == null) return false;
    _notes.addAll(notes);
    await _persistDraft();
    return true;
  }

  String nameOf(String mssv) => _students
      .firstWhere(
        (s) => s.mssv == mssv,
        orElse: () => EmsRosterStudent(mssv: mssv, fullName: mssv),
      )
      .fullName;

  @override
  void dispose() {
    _disposed = true;
    _finishedSub?.cancel();
    super.dispose();
  }
}
