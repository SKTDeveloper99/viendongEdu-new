// lib/screens/ems_attendance_teacher_screen.dart
//
// Điểm danh EMS — EMS là nguồn dữ liệu điểm danh chính thức.
//
// Vì sao tồn tại: ngày 07/09/2026, sáu học viên lớp 08CD15BEP4C quẹt cổng từ
// 07:05 đến 07:30 rồi bị ghi VẮNG bằng một lần lưu hàng loạt lúc 09:07:48–51.
// IMS không có gì phản đối, vì IMS không thể. Ở đây thì có:
//
//   • CHƯA ĐIỂM DANH không phải là VẮNG. Không chọn gì thì không ghi gì.
//   • Trường hợp lạ vẫn được lưu, kèm lý do/cờ để xem lại sau.
//   • Lưu lại bao nhiêu lần cũng chỉ một dòng; lưu muộn vẫn lưu được.
//
// Giáo viên vẫn là người quyết định cuối cùng. Máy chỉ từ chối im lặng.

import 'dart:async';

import 'package:flutter/material.dart';
import '../services/ems_attendance_cache.dart';
import '../services/ems_api_service.dart';
import '../utils/vietnamese_text.dart';

class EmsAttendanceTeacherScreen extends StatefulWidget {
  const EmsAttendanceTeacherScreen({super.key});

  @override
  State<EmsAttendanceTeacherScreen> createState() =>
      _EmsAttendanceTeacherScreenState();
}

class _EmsAttendanceTeacherScreenState
    extends State<EmsAttendanceTeacherScreen> {
  static const _orange = Color(0xFFE65100);

  bool _loading = true;
  bool _usingCache = false;
  String? _error;
  List<EmsSession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final date = _todayHcm();
    final cached = await EmsAttendanceCache.loadTeacherSessions(date);
    try {
      final s = await EmsApiService.mySessions();
      await EmsAttendanceCache.saveTeacherSessions(date, s);
      if (!mounted) return;
      setState(() {
        _sessions = s;
        _usingCache = false;
        _loading = false;
      });
    } on EmsException catch (e) {
      if (!mounted) return;
      setState(() {
        _sessions = cached;
        _usingCache = cached.isNotEmpty;
        _error = cached.isEmpty ? e.message : null;
        _loading = false;
      });
    }
  }

  static String _todayHcm() {
    final d = DateTime.now().toUtc().add(const Duration(hours: 7));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: const Text('Điểm danh EMS'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off,
        title: 'Không tải được danh sách buổi dạy',
        detail: _error!,
        onRetry: _load,
      );
    }
    if (_sessions.isEmpty) {
      return const _Message(
        icon: Icons.event_busy,
        title: 'Hôm nay bạn không có buổi học',
        detail: 'Buổi học lấy theo thời khoá biểu. Kéo xuống để tải lại.',
      );
    }
    return RefreshIndicator(
      color: _orange,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _sessions.length + (_usingCache ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (_usingCache && i == 0) {
            return const _OfflineBanner(
              text:
                  'Đang dùng danh sách đã lưu trên máy. Có thể mở lớp và '
                  'điểm danh; dữ liệu sẽ tự gửi khi có mạng.',
            );
          }
          return _sessionCard(_sessions[i - (_usingCache ? 1 : 0)]);
        },
      ),
    );
  }

  Widget _sessionCard(EmsSession s) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _RosterScreen(session: s)),
          );
          if (mounted) _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.subjectName?.isNotEmpty == true
                          ? s.subjectName!
                          : s.sectionCode,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (s.isMarked || s.reportState != 'open')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s.reportState == 'final'
                            ? 'Đã chốt ${s.markedCount}'
                            : 'Đã gửi ${s.markedCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.sectionCode,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    s.timeLabel,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.groups, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${s.rosterSize}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  if (s.room?.isNotEmpty == true) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.place, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        s.room!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Danh sách lớp ────────────────────────────────────────────────────────────

class _RosterScreen extends StatefulWidget {
  final EmsSession session;
  const _RosterScreen({required this.session});

  @override
  State<_RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<_RosterScreen>
    with WidgetsBindingObserver {
  static const _orange = Color(0xFFE65100);
  static const _green = Color(0xFF2E7D32);
  static const _red = Color(0xFFC62828);

  bool _loading = true;
  bool _saving = false;
  bool _queued = false;
  bool _usingCache = false;
  String? _error;
  List<EmsRosterStudent> _students = const [];
  DateTime? _scanSyncedAt;
  Timer? _retryTimer;

  /// mssv -> 'present' | 'absent'. Vắng mặt trong map = CHƯA ĐIỂM DANH.
  final Map<String, String> _marks = {};
  final Map<String, String> _notes = {};

  /// 18/09 (Dũng): giáo viên điểm danh tay muốn dò tên theo A–Z. Mặc định
  /// giữ thứ tự danh sách lớp của IMS; bật nút trên thanh tiêu đề để xếp
  /// theo TÊN (chữ cuối) rồi họ, bỏ dấu khi so sánh.
  bool _sortAz = false;

  List<EmsRosterStudent> get _visibleStudents {
    if (!_sortAz) return _students;
    final sorted = List<EmsRosterStudent>.of(_students);
    sorted.sort((a, b) {
      final c = _sortKey(a.fullName).compareTo(_sortKey(b.fullName));
      return c != 0 ? c : a.mssv.compareTo(b.mssv);
    });
    return sorted;
  }

  /// "Nguyễn Thị Lan Phương" -> "phuong|nguyen thi lan phuong".
  static String _sortKey(String fullName) {
    final plain = stripVietnamese(fullName).toLowerCase().trim();
    final parts = plain.split(RegExp(r'\s+'));
    final given = parts.isEmpty ? '' : parts.last;
    return '$given|$plain';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _retryTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _retryQueued(),
    );
    _load();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _retryQueued();
  }

  String get _draftKey => widget.session.sessionKey.isNotEmpty
      ? widget.session.sessionKey
      : '${widget.session.sectionId}:${widget.session.startTime ?? 'na'}:'
            '${widget.session.sessionDate}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final draft = await EmsAttendanceCache.loadDraft(_draftKey);
    try {
      final r = await EmsApiService.roster(widget.session);
      if (!mounted) return;
      setState(() {
        _students = r.students;
        _scanSyncedAt = r.scanSyncedAt;
        _marks.clear();
        for (final s in r.students) {
          if (s.status != null) _marks[s.mssv] = s.status!;
          if (s.note != null) _notes[s.mssv] = s.note!;
        }
        if (draft != null) {
          _marks.addAll(draft.marks);
          _notes.addAll(draft.notes);
          _queued = draft.queued;
        }
        _usingCache = false;
        _loading = false;
      });
      await _persistDraft();
      if (_queued) unawaited(_retryQueued());
    } on EmsException catch (e) {
      if (!mounted) return;
      setState(() {
        if (draft != null && draft.students.isNotEmpty) {
          _students = draft.students;
          _marks
            ..clear()
            ..addAll(draft.marks);
          _notes
            ..clear()
            ..addAll(draft.notes);
          _queued = draft.queued;
          _usingCache = true;
          _error = null;
        } else {
          _error = e.message;
        }
        _loading = false;
      });
    }
  }

  int get _presentCount => _marks.values.where((v) => v == 'present').length;
  int get _absentCount => _marks.values.where((v) => v == 'absent').length;
  int get _lateCount => _marks.values.where((v) => v == 'late').length;
  int get _excusedCount => _marks.values.where((v) => v == 'excused').length;
  int get _unmarkedCount => _students.length - _marks.length;
  int get _scannedCount => _students.where((s) => s.scanned).length;
  int get _unscannedCount => _students.length - _scannedCount;
  bool get _allPresent =>
      _students.isNotEmpty &&
      _students.every((s) => _marks[s.mssv] == 'present');

  Future<void> _persistDraft() => EmsAttendanceCache.saveDraft(
    _draftKey,
    _marks,
    _notes,
    queued: _queued,
    students: _students,
  );

  void _select(String mssv, String? status) {
    setState(() {
      if (status == null) {
        _marks.remove(mssv);
      } else {
        _marks[mssv] = status;
      }
    });
    unawaited(_persistDraft());
  }

  void _markScannedPresent() {
    setState(() {
      for (final s in _students) {
        if (s.scanned && !_marks.containsKey(s.mssv)) {
          _marks[s.mssv] = 'present';
        }
      }
    });
    unawaited(_persistDraft());
  }

  void _markAllPresent() {
    setState(() {
      for (final s in _students) {
        _marks[s.mssv] = 'present';
      }
    });
    unawaited(_persistDraft());
  }

  /// Bấm nhầm "Tất cả có mặt" (Dũng, 18/09): quay về đúng chỗ trước khi bấm —
  /// ai máy chủ đã lưu thì giữ dấu đã lưu, ai đã quẹt cổng thì có mặt, còn
  /// lại CHƯA ĐIỂM DANH. Không bao giờ xoá dấu đã lưu chỉ vì bỏ chọn.
  void _resetToScanned() {
    setState(() {
      _marks.clear();
      for (final s in _students) {
        if (s.status != null) {
          _marks[s.mssv] = s.status!;
        } else if (s.scanned) {
          _marks[s.mssv] = 'present';
        }
      }
    });
    unawaited(_persistDraft());
  }

  // Học viên đã có điểm danh trên máy chủ nhưng nay bị BỎ CHỌN. Gửi kèm để máy
  // chủ xoá — nếu chỉ bỏ khỏi danh sách gửi, dấu điểm danh cũ vẫn còn (đúng là
  // lỗi "chọn tất cả -> bỏ vài người -> lưu lại mà vẫn có mặt").
  List<String> get _toRemove => _students
      .where((s) => s.status != null && !_marks.containsKey(s.mssv))
      .map((s) => s.mssv)
      .toList();

  Future<void> _save() async {
    if (_marks.isEmpty && _toRemove.isEmpty) {
      _toast('Chưa chọn gì để lưu.');
      return;
    }
    // 17/09 (Huy, lớp 43461): 12 học viên chưa chạm tới, bấm Lưu vẫn xanh.
    // Máy chủ KHÔNG ghi vắng người chưa điểm danh — nhưng thầy/cô tưởng đã
    // xong. Hỏi rõ trước khi lưu thiếu; không bao giờ tự ghi vắng thay.
    if (_unmarkedCount > 0) {
      final go = await _confirmUnmarked();
      if (!go) return;
    }
    setState(() {
      _saving = true;
      _queued = true;
      _needsReason = null;
    });
    await _persistDraft();
    try {
      await _sendMarks();
    } on EmsPunchConflict catch (c) {
      // Không phải lỗi — máy đang hỏi. Hỏi lý do rồi gửi lại đúng một lần.
      final ok = await _askReasons(c.students);
      if (ok) {
        try {
          await _sendMarks();
        } on EmsPunchConflict catch (c2) {
          _holdForReason(c2);
        } on EmsException catch (e) {
          _toast(e.message);
        }
      } else {
        // Thầy/cô đóng hộp thoại: KHÔNG được để hàng đợi tự gửi lại y hệt
        // mỗi 20 giây (17/09, Hậu: bốn lần 422 trong 30 giây).
        _holdForReason(c);
      }
    } on EmsException catch (e) {
      if (_isClientRefusal(e)) {
        // 4xx là câu trả lời dứt khoát của máy chủ; gửi lại y hệt vô ích.
        setState(() => _queued = false);
        await _persistDraft();
        _toast('Máy chủ từ chối: ${e.message}');
      } else {
        _toast('Đã giữ trên điện thoại; sẽ tự gửi khi có mạng. ${e.message}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Danh sách học viên đã quẹt cổng mà bị ghi vắng, máy chủ đang chờ lý do.
  /// Khi khác null: hàng đợi tắt, thanh dưới nhắc; bấm Lưu để nêu lý do.
  List<EmsPunchedStudent>? _needsReason;

  void _holdForReason(EmsPunchConflict c) {
    if (!mounted) return;
    setState(() {
      _queued = false;
      _needsReason = c.students;
    });
    unawaited(_persistDraft());
    _toast(
      'CHƯA LƯU — ${c.students.length} học viên đã quẹt cổng nhưng ghi vắng. '
      'Bấm Lưu để nêu lý do.',
    );
  }

  /// 401 = token hết hạn (thử lại được). 4xx khác = máy chủ đã trả lời "không";
  /// gửi lại nguyên xi chỉ tạo thêm dòng từ chối trong nhật ký.
  static bool _isClientRefusal(EmsException e) {
    final c = e.statusCode;
    return c != null && c >= 400 && c < 500 && c != 401 && c != 408 && c != 429;
  }

  Future<bool> _confirmUnmarked() async {
    final undecided = _students
        .where((s) => !_marks.containsKey(s.mssv))
        .toList();
    final chosen = _marks.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Còn ${undecided.length} học viên chưa điểm danh'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Những học viên này sẽ KHÔNG được ghi có mặt hay vắng — '
                'buổi học của họ để trống. Nếu họ vắng, hãy quay lại và chọn '
                '"Vắng" cho từng người.',
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              ),
              const SizedBox(height: 10),
              for (final s in undecided.take(12))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• ${s.fullName} (${s.mssv})',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              if (undecided.length > 12)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '… và ${undecided.length - 12} học viên nữa',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _orange),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại điểm danh'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Lưu $chosen đã chọn, để trống số còn lại'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _sendMarks() async {
    final marks = _marks.entries.map((e) {
      final student = _students.where((s) => s.mssv == e.key).firstOrNull;
      return EmsMark(
        mssv: e.key,
        status: e.value,
        note: _notes[e.key],
        punchId: student?.punchId,
      );
    }).toList();
    final removeList = _toRemove;
    final res = await EmsApiService.saveMarks(
      widget.session,
      marks,
      remove: removeList,
    );
    // A 200 response is not enough. Read the session back and prove every row
    // survived — and that every removed one is actually gone — before telling
    // the teacher it is safely stored.
    final confirmed = await EmsApiService.roster(widget.session);
    final byMssv = {for (final s in confirmed.students) s.mssv: s.status};
    final missing = marks.where((m) => byMssv[m.mssv] != m.status).toList();
    final stillThere = removeList
        .where((mssv) => byMssv[mssv] != null)
        .toList();
    if (stillThere.isNotEmpty) {
      throw EmsException(
        'Máy chủ chưa bỏ điểm danh ${stillThere.length} học viên; ứng dụng sẽ gửi lại.',
      );
    }
    if (missing.isNotEmpty) {
      throw EmsException(
        'Máy chủ chưa xác nhận đủ ${missing.length} học viên; ứng dụng sẽ gửi lại.',
      );
    }
    await EmsAttendanceCache.clearDraft(_draftKey);
    if (!mounted) return;
    setState(() {
      _students = confirmed.students;
      _queued = false;
      _needsReason = null;
    });
    final late = res.late ? ' (ghi muộn)' : '';
    final over = res.overriddenPunches.isEmpty
        ? ''
        : ' • ${res.overriddenPunches.length} ca ghi vắng dù đã quẹt cổng';
    _toast('Đã lưu ${res.saved} dòng$late$over', good: true);
  }

  Future<void> _retryQueued() async {
    if (!_queued || _saving || _loading || _marks.isEmpty) return;
    if (mounted) setState(() => _saving = true);
    try {
      await _sendMarks();
    } on EmsPunchConflict catch (c) {
      // Máy chủ đang HỎI, không phải mạng yếu. Dừng hàng đợi, để thầy/cô
      // bấm Lưu và trả lời — không hỏi hộ, không gửi lại y hệt.
      _holdForReason(c);
    } on EmsException catch (e) {
      if (_isClientRefusal(e)) {
        if (mounted) setState(() => _queued = false);
        await _persistDraft();
        _toast('Máy chủ từ chối: ${e.message}');
      }
      // Còn lại là mạng yếu như dự kiến. Hàng đợi bền giữ cho lần thử sau.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Bắt buộc nêu lý do cho từng học viên đã quẹt cổng mà bị ghi vắng.
  /// Trả về true nếu đã điền đủ.
  Future<bool> _askReasons(List<EmsPunchedStudent> people) async {
    // Hộp thoại TỰ giữ controller và tự dispose trong dispose() của chính nó.
    //
    // Trước đây controller được tạo ở đây rồi dispose ngay sau await
    // showDialog. Nhưng showDialog trả về NGAY khi Navigator.pop chạy, trong
    // khi hộp thoại vẫn đang chạy hoạt ảnh đóng và các TextField vẫn còn sống
    // và vẫn đang dùng controller đó -> Flutter ném '_dependents.isEmpty'
    // (màn hình đỏ) đúng vào lúc thầy/cô bấm "Lưu kèm lý do".
    final notes = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _ReasonsDialog(people: people, initial: _notes, nameOf: _nameOf),
    );
    if (notes == null) return false;
    _notes.addAll(notes);
    await _persistDraft();
    return true;
  }

  String _nameOf(String mssv) => _students
      .firstWhere(
        (s) => s.mssv == mssv,
        orElse: () => EmsRosterStudent(mssv: mssv, fullName: mssv),
      )
      .fullName;

  static String _hhmm(DateTime d) {
    final school = d.toUtc().add(const Duration(hours: 7));
    return '${school.hour.toString().padLeft(2, '0')}:'
        '${school.minute.toString().padLeft(2, '0')}';
  }

  void _toast(String msg, {bool good = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: good ? _green : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: Text(
          widget.session.subjectName?.isNotEmpty == true
              ? widget.session.subjectName!
              : widget.session.sectionCode,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: _sortAz ? 'Thứ tự danh sách lớp' : 'Xếp tên A–Z',
            onPressed: () => setState(() => _sortAz = !_sortAz),
            icon: Icon(
              Icons.sort_by_alpha,
              color: _sortAz ? Colors.white : Colors.white70,
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _loading || _error != null ? null : _bottomBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off,
        title: 'Không tải được danh sách lớp',
        detail: _error!,
        onRetry: _load,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: _students.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) =>
          i == 0 ? _quickActions() : _studentRow(_visibleStudents[i - 1]),
    );
  }

  Widget _quickActions() {
    // "Quẹt cổng: có mặt (0)" từng đếm người đã quẹt NHƯNG chưa đánh dấu —
    // vừa đánh xong là về 0, giáo viên tưởng máy nói không ai quẹt (Dũng,
    // 18/09). Nay: tổng đã quẹt / chưa quẹt luôn hiện, nút chỉ nói còn
    // bao nhiêu người đã quẹt mà chưa được đánh có mặt.
    final scansPending = _students
        .where((s) => s.scanned && !_marks.containsKey(s.mssv))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_usingCache)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: _OfflineBanner(
              text:
                  'Không có mạng: đang dùng danh sách đã lưu. Cứ điểm danh '
                  'bình thường; điện thoại sẽ tự gửi lại.',
            ),
          ),
        // Giờ đồng bộ quẹt cổng: giáo viên đối chiếu được "đã quẹt" là tính
        // tới lúc nào, thay vì đoán danh sách trống nghĩa là không ai quẹt.
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            _scanSyncedAt == null
                ? 'Lấy quẹt cổng: chưa có dữ liệu'
                : 'Lấy quẹt cổng lúc ${_hhmm(_scanSyncedAt!)} — chưa quẹt KHÔNG phải vắng',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Đã quẹt $_scannedCount • Chưa quẹt $_unscannedCount • Sĩ số ${_students.length}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF444444),
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: scansPending == 0 ? null : _markScannedPresent,
              icon: const Icon(Icons.sensor_door_outlined, size: 16),
              label: Text(
                scansPending == 0
                    ? 'Đã quẹt → có mặt (xong)'
                    : 'Đã quẹt → có mặt (còn $scansPending)',
              ),
            ),
            _allPresent
                ? OutlinedButton.icon(
                    onPressed: _resetToScanned,
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Bỏ chọn tất cả'),
                  )
                : OutlinedButton.icon(
                    onPressed: _students.isEmpty ? null : _markAllPresent,
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Tất cả có mặt'),
                  ),
          ],
        ),
      ],
    );
  }

  static String _hhmmss(DateTime d) {
    final school = d.toUtc().add(const Duration(hours: 7));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(school.hour)}:${two(school.minute)}:${two(school.second)} '
        '${two(school.day)}/${two(school.month)}/${school.year}';
  }

  static String _markLabel(String? mark) => switch (mark) {
    'present' => 'Có mặt',
    'absent' => 'Vắng',
    'late' => 'Đi trễ',
    'excused' => 'Vắng có phép',
    _ => 'Chưa điểm danh',
  };

  /// Chạm vào học viên: xem giờ quẹt cổng chính xác (tới giây) và trạng thái
  /// hiện tại, để giáo viên đối chiếu khi học viên khiếu nại "em có quẹt mà".
  void _showStudentDetail(EmsRosterStudent s) {
    final mark = _marks[s.mssv];
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.fullName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              s.mssv + (s.classCode == null ? '' : ' • ${s.classCode}'),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const Divider(height: 24),
            _detailRow(
              Icons.sensor_door_outlined,
              'Quẹt cổng',
              !s.scanned
                  ? 'Chưa quẹt hôm nay (không phải vắng)'
                  : s.scannedAt == null
                  ? 'Đã quẹt (không có giờ)'
                  : _hhmmss(s.scannedAt!),
              color: s.scanned ? _green : Colors.grey[600]!,
            ),
            const SizedBox(height: 10),
            _detailRow(
              Icons.how_to_reg_outlined,
              'Điểm danh',
              _markLabel(mark),
              color: mark == 'present'
                  ? _green
                  : mark == 'absent'
                  ? _red
                  : Colors.grey[700]!,
            ),
            if (_scanSyncedAt != null) ...[
              const SizedBox(height: 10),
              _detailRow(
                Icons.sync,
                'Lấy quẹt cổng lúc',
                _hhmmss(_scanSyncedAt!),
                color: Colors.grey[600]!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    required Color color,
  }) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      const Spacer(),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    ],
  );

  Widget _studentRow(EmsRosterStudent s) {
    final mark = _marks[s.mssv];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showStudentDetail(s),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          s.mssv,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (s.scanned) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.sensor_door_outlined,
                            size: 13,
                            color: _green,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            s.scannedAt == null
                                ? 'đã quẹt cổng'
                                : 'quẹt ${_hhmm(s.scannedAt!)}',
                            style: const TextStyle(fontSize: 11, color: _green),
                          ),
                        ],
                      ],
                    ),
                    if (mark == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'chưa điểm danh',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _pill(
                label: 'Có',
                selected: mark == 'present',
                color: _green,
                onTap: () => _select(s.mssv, 'present'),
              ),
              const SizedBox(width: 6),
              _pill(
                label: 'Vắng',
                selected: mark == 'absent',
                color: _red,
                onTap: () => _select(s.mssv, 'absent'),
              ),
              PopupMenuButton<String>(
                tooltip: 'Trạng thái khác',
                onSelected: (value) =>
                    _select(s.mssv, value == 'unmarked' ? null : value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'late', child: Text('Đi trễ')),
                  PopupMenuItem(value: 'excused', child: Text('Vắng có phép')),
                  PopupMenuItem(
                    value: 'unmarked',
                    child: Text('Chưa điểm danh'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_queued ? 'Đã giữ trên máy • chờ gửi\n' : ''}'
                '${_needsReason != null ? 'CHƯA LƯU • ${_needsReason!.length} SV quẹt cổng bị ghi vắng, cần lý do\n' : ''}'
                'Có $_presentCount • Trễ $_lateCount • Phép $_excusedCount • '
                'Vắng $_absentCount • Chưa điểm danh $_unmarkedCount',
                style: TextStyle(
                  fontSize: 12,
                  color: _needsReason != null ? _red : null,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _orange),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Lưu điểm danh'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dùng chung ───────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3E0),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off, size: 18, color: Color(0xFFE65100)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hỏi lý do cho từng học viên đã quẹt cổng mà bị ghi vắng.
///
/// Là StatefulWidget để controller sống và chết CÙNG hộp thoại — đó là lý do
/// duy nhất nó tồn tại tách khỏi màn hình cha.
class _ReasonsDialog extends StatefulWidget {
  const _ReasonsDialog({
    required this.people,
    required this.initial,
    required this.nameOf,
  });

  final List<EmsPunchedStudent> people;
  final Map<String, String> initial;
  final String Function(String mssv) nameOf;

  @override
  State<_ReasonsDialog> createState() => _ReasonsDialogState();
}

class _ReasonsDialogState extends State<_ReasonsDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final p in widget.people)
      p.mssv: TextEditingController(text: widget.initial[p.mssv] ?? ''),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _hhmm(DateTime d) {
    final school = d.toUtc().add(const Duration(hours: 7));
    return '${school.hour.toString().padLeft(2, '0')}:'
        '${school.minute.toString().padLeft(2, '0')}';
  }

  bool get _complete =>
      _controllers.values.every((c) => c.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cần nêu lý do'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Những học viên này đã quẹt thẻ vào trường hôm nay. '
              'Thầy/cô vẫn có quyền ghi VẮNG — chỉ cần cho biết vì sao, '
              'và lý do sẽ được lưu lại.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final p in widget.people) ...[
              Text(
                widget.nameOf(p.mssv),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                p.punchedAt == null
                    ? p.mssv
                    : '${p.mssv} • quẹt lúc ${_hhmm(p.punchedAt!)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              TextField(
                controller: _controllers[p.mssv],
                // Nút "Lưu" bật/tắt theo ô trống, thay vì im lặng không ăn.
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Ví dụ: quẹt cổng nhưng không vào lớp',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _complete
              ? () => Navigator.pop(context, {
                  for (final e in _controllers.entries)
                    e.key: e.value.text.trim(),
                })
              : null,
          child: const Text('Lưu kèm lý do'),
        ),
      ],
    );
  }
}
