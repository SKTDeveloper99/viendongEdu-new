// lib/screens/ems_attendance_teacher_screen.dart
//
// Điểm danh EMS (THỬ NGHIỆM) — màn hình song song, không thay IMS.
//
// Vì sao tồn tại: ngày 07/09/2026, sáu học viên lớp 08CD15BEP4C quẹt cổng từ
// 07:05 đến 07:30 rồi bị ghi VẮNG bằng một lần lưu hàng loạt lúc 09:07:48–51.
// IMS không có gì phản đối, vì IMS không thể. Ở đây thì có:
//
//   • CHƯA ĐIỂM DANH không phải là VẮNG. Không chọn gì thì không ghi gì.
//   • Ghi VẮNG cho người ĐÃ QUẸT CỔNG thì phải nêu lý do, và lý do được lưu.
//   • Lưu lại bao nhiêu lần cũng chỉ một dòng; lưu muộn vẫn lưu được.
//
// Giáo viên vẫn là người quyết định cuối cùng. Máy chỉ từ chối im lặng.

import 'package:flutter/material.dart';
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
    try {
      final s = await EmsApiService.mySessions();
      if (!mounted) return;
      setState(() {
        _sessions = s;
        _loading = false;
      });
    } on EmsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: const Text('Điểm danh EMS (thử nghiệm)'),
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
        itemCount: _sessions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _sessionCard(_sessions[i]),
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
                  if (s.isMarked)
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
                        'Đã ghi ${s.markedCount}',
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

class _RosterScreenState extends State<_RosterScreen> {
  static const _orange = Color(0xFFE65100);
  static const _green = Color(0xFF2E7D32);
  static const _red = Color(0xFFC62828);

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<EmsRosterStudent> _students = const [];

  /// mssv -> 'present' | 'absent'. Vắng mặt trong map = CHƯA ĐIỂM DANH.
  final Map<String, String> _marks = {};
  final Map<String, String> _notes = {};

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
        _loading = false;
      });
    } on EmsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  int get _presentCount => _marks.values.where((v) => v == 'present').length;
  int get _absentCount => _marks.values.where((v) => v == 'absent').length;
  int get _unmarkedCount => _students.length - _marks.length;

  Future<void> _save() async {
    if (_marks.isEmpty) {
      _toast('Chưa chọn gì để lưu.');
      return;
    }
    setState(() => _saving = true);
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
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendMarks() async {
    final marks = _marks.entries
        .map((e) => EmsMark(mssv: e.key, status: e.value, note: _notes[e.key]))
        .toList();
    final res = await EmsApiService.saveMarks(widget.session, marks);
    if (!mounted) return;
    final late = res.late ? ' (ghi muộn)' : '';
    final over = res.overriddenPunches.isEmpty
        ? ''
        : ' • ${res.overriddenPunches.length} ca ghi vắng dù đã quẹt cổng';
    _toast('Đã lưu ${res.saved} dòng$late$over', good: true);
    await _load();
  }

  /// Bắt buộc nêu lý do cho từng học viên đã quẹt cổng mà bị ghi vắng.
  /// Trả về true nếu đã điền đủ.
  Future<bool> _askReasons(List<EmsPunchedStudent> people) async {
    final controllers = {
      for (final p in people)
        p.mssv: TextEditingController(text: _notes[p.mssv] ?? ''),
    };
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
              for (final p in people) ...[
                Text(
                  _nameOf(p.mssv),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  p.punchedAt == null
                      ? p.mssv
                      : '${p.mssv} • quẹt lúc ${_hhmm(p.punchedAt!)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                TextField(
                  controller: controllers[p.mssv],
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              final missing = controllers.values.any(
                (c) => c.text.trim().isEmpty,
              );
              if (missing) return; // im lặng: nút không ăn khi còn ô trống
              Navigator.pop(ctx, true);
            },
            child: const Text('Lưu kèm lý do'),
          ),
        ],
      ),
    );
    if (ok == true) {
      for (final e in controllers.entries) {
        _notes[e.key] = e.value.text.trim();
      }
    }
    for (final c in controllers.values) {
      c.dispose();
    }
    return ok == true;
  }

  String _nameOf(String mssv) => _students
      .firstWhere(
        (s) => s.mssv == mssv,
        orElse: () => EmsRosterStudent(mssv: mssv, fullName: mssv),
      )
      .fullName;

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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
      itemCount: _students.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _studentRow(_students[i]),
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
            onTap: () => setState(() => _marks[s.mssv] = 'present'),
          ),
          const SizedBox(width: 6),
          _pill(
            label: 'Vắng',
            selected: mark == 'absent',
            color: _red,
            onTap: () => setState(() => _marks[s.mssv] = 'absent'),
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
                'Có $_presentCount • Vắng $_absentCount • Chưa $_unmarkedCount',
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
