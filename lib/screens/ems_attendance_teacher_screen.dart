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
        title: 'Hôm nay chưa có buổi dạy nào trong hệ thống',
        detail:
            'Đây có thể là ngày trống, cũng có thể là lớp chưa được nối vào '
            'EMS. Không phải lỗi của bạn.',
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
  Timer? _retryTimer;

  /// mssv -> 'present' | 'absent'. Vắng mặt trong map = CHƯA ĐIỂM DANH.
  final Map<String, String> _marks = {};
  final Map<String, String> _notes = {};

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
    setState(() {
      _saving = true;
      _queued = true;
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
        } on EmsException catch (e) {
          _toast(e.message);
        }
      }
    } on EmsException catch (e) {
      _toast('Đã giữ trên điện thoại; sẽ tự gửi khi có mạng. ${e.message}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final res = await EmsApiService.saveMarks(widget.session, marks, remove: removeList);
    // A 200 response is not enough. Read the session back and prove every row
    // survived — and that every removed one is actually gone — before telling
    // the teacher it is safely stored.
    final confirmed = await EmsApiService.roster(widget.session);
    final byMssv = {for (final s in confirmed.students) s.mssv: s.status};
    final missing = marks.where((m) => byMssv[m.mssv] != m.status).toList();
    final stillThere = removeList.where((mssv) => byMssv[mssv] != null).toList();
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
    } on EmsException {
      // Expected on weak internet. The durable queue remains for next retry.
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
          i == 0 ? _quickActions() : _studentRow(_students[i - 1]),
    );
  }

  Widget _quickActions() {
    final scans = _students
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
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: scans == 0 ? null : _markScannedPresent,
              icon: const Icon(Icons.sensor_door_outlined, size: 16),
              label: Text('Quẹt cổng: có mặt ($scans)'),
            ),
            OutlinedButton.icon(
              onPressed: _students.isEmpty ? null : _markAllPresent,
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('Tất cả có mặt'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _studentRow(EmsRosterStudent s) {
    final mark = _marks[s.mssv];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
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
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
              PopupMenuItem(value: 'unmarked', child: Text('Chưa điểm danh')),
            ],
          ),
        ],
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
                'Có $_presentCount • Trễ $_lateCount • Phép $_excusedCount • '
                'Vắng $_absentCount • Chưa $_unmarkedCount',
                style: const TextStyle(fontSize: 12),
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
