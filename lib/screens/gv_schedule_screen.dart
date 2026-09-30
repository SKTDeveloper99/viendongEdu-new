import 'package:flutter/material.dart';
import '../services/crm_teacher_api.dart';
import '../services/crm_session_guard.dart';
import '../services/app_session.dart';
import '../components/skeleton.dart';
import '../utils/snack.dart';
import '../features/teacher_attendance/teacher_attendance_screen.dart';
import '../theme/vd_tokens.dart';

class GvScheduleScreen extends StatefulWidget {
  const GvScheduleScreen({super.key});
  @override
  State<GvScheduleScreen> createState() => _GvScheduleScreenState();
}

class _GvScheduleScreenState extends State<GvScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  late DateTime _currentMonday;
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;
  String? _error;
  final ScrollController _chipScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentMonday = _findMonday(DateTime.now());
    _fetch(_selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void dispose() {
    _chipScroll.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_chipScroll.hasClients) return;
    final weekDays = _weekDays;
    int index = weekDays.indexWhere((d) => _fmtDate(d) == _fmtDate(_selectedDate));
    if (index == -1) return;
    const chipWidth = 60.0;
    const chipMargin = 8.0;
    final chipOffset = index * (chipWidth + chipMargin);
    final viewport = _chipScroll.position.viewportDimension;
    final center = (chipOffset - viewport / 2 + chipWidth / 2)
        .clamp(0.0, _chipScroll.position.maxScrollExtent);
    _chipScroll.animateTo(center,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _fetch(DateTime date) async {
    setState(() { _loading = true; _error = null; });
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final data = await CrmTeacherApi.scheduleForDate(dateStr);
      if (!mounted) return;
      setState(() {
        _classes = data.map((e) => e.toJson()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  DateTime _findMonday(DateTime d) => d.subtract(Duration(days: d.weekday - 1));
  List<DateTime> get _weekDays => List.generate(7, (i) => _currentMonday.add(Duration(days: i)));
  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _prevWeek() {
    setState(() => _currentMonday = _currentMonday.subtract(const Duration(days: 7)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _nextWeek() {
    setState(() => _currentMonday = _currentMonday.add(const Duration(days: 7)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _fetch(date);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: context.vd.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _currentMonday = _findMonday(picked));
      _selectDate(picked);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vd.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickDate,
        backgroundColor: context.vd.primary,
        icon: Icon(Icons.calendar_month, color: context.vd.onPrimary, size: 20),
        label: Text(
          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
          style: TextStyle(color: context.vd.onPrimary, fontSize: 13),
        ),
      ),
      body: SafeArea(top: false, child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.vd.primary, context.vd.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.arrow_back_ios,
                          color: context.vd.onPrimary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lịch dạy',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.vd.onPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Week navigator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _prevWeek,
                      child: Icon(Icons.chevron_left,
                          color: context.vd.onPrimary, size: 28),
                    ),
                    Text(
                      () {
                        final s = _currentMonday;
                        final e = _currentMonday.add(const Duration(days: 6));
                        return '${s.day}/${s.month} – ${e.day}/${e.month}/${e.year}';
                      }(),
                      style: TextStyle(
                        color: context.vd.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: _nextWeek,
                      child: Icon(Icons.chevron_right,
                          color: context.vd.onPrimary, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Day chips
                SizedBox(
                  height: 84,
                  child: ListView.builder(
                    controller: _chipScroll,
                    scrollDirection: Axis.horizontal,
                    itemCount: _weekDays.length,
                    itemBuilder: (context, i) {
                      final day = _weekDays[i];
                      final isSelected = _fmtDate(day) == _fmtDate(_selectedDate);
                      final isToday = _fmtDate(day) == _fmtDate(DateTime.now());
                      return GestureDetector(
                        onTap: () => _selectDate(day),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.vd.surface
                                : context.vd.surface.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ['T2','T3','T4','T5','T6','T7','CN'][day.weekday - 1],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? context.vd.primary
                                      : context.vd.onPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? context.vd.primary
                                      : context.vd.onPrimary,
                                ),
                              ),
                              if (isToday)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(top: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? context.vd.primary
                                        : context.vd.surface,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: _loading
                ? skeletonList()
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: context.vd.inkFaint),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style:
                                    TextStyle(color: context.vd.inkFaint)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _fetch(_selectedDate),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      context.vd.primary),
                              child: Text('Thử lại',
                                  style:
                                      TextStyle(color: context.vd.onPrimary)),
                            ),
                          ],
                        ),
                      )
                    : _classes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_busy,
                                    size: 64, color: context.vd.inkFaint),
                                SizedBox(height: 12),
                                Text('Không có lịch dạy',
                                    style:
                                        TextStyle(color: context.vd.inkFaint)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _fetch(_selectedDate),
                            color: context.vd.primary,
                            child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                                16, 16, 16, 24),
                            itemCount: _classes.length,
                            itemBuilder: (ctx, i) =>
                                _ScheduleCard(data: _classes[i]),
                          ),
                        ),
          ),
        ],
      )),
    );
  }
}

// ── Schedule Card ────────────────────────────────────────
({String label, Color color}) _buoiInfo(BuildContext context, String? b) => switch (b) {
      'S' => (label: 'Sáng', color: context.vd.info),
      'C' => (label: 'Chiều', color: context.vd.warning),
      'T' => (label: 'Tối', color: context.vd.evening),
      _ => (label: '', color: context.vd.inkFaint),
    };

class _ScheduleCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ScheduleCard({required this.data});

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  bool _expanded = false;
  bool _loading = false;

  Future<void> _openAttendance() async {
    setState(() => _loading = true);
    try {
      // ── CUTOVER 2026-09-12: điểm danh ghi vào EMS, không ghi vào IMS ───────
      //
      // IMS chỉ còn là nơi LẤY danh sách học viên của lớp môn học (đã scrape sang
      // `enrollments`, khớp 612/613 lớp HK261 theo ims_lop_mon_hoc_id). Việc GHI
      // điểm danh chuyển hẳn sang EMS.
      //
      // Vì sao phải chuyển chứ không vá tiếp: `giangvien/diemdanh/luu` của IMS là
      // INSERT chứ không phải UPSERT, nên lưu hai lần là sinh ra hai bản ghi mâu
      // thuẫn. Đo trên IMS thật ngày 09/09/2026: từ 01/08 có 11.075 nhóm trùng /
      // 31.462 dòng, 2.633 mâu thuẫn trên 1.490 học viên, và 1.250 trường hợp
      // dòng VẮNG thắng — 916 em đang bị báo vắng dù có đi học. Bản vá phía app
      // (a07222a) làm giảm, nhưng KHÔNG thể diệt: endpoint không idempotent thì
      // mạng chập chờn vẫn ghi trùng.
      // `attendance_marks` của EMS có UNIQUE (session_key, mssv), nên lưu hai lần
      // là KHÔNG THỂ tạo ra dòng thứ hai. Đó là lý do chuyển, không phải vì mới.
      //
      // Token EMS đã được AppSession đổi từ token IMS lúc đăng nhập
      // (mirrorTeacher), nên giáo viên KHÔNG phải đăng nhập thêm lần nào.
      // A missing EMS session must fail closed. The old IMS endpoint inserts
      // duplicates and cannot truthfully confirm an EMS save.
      if (!AppSession.instance.hasEms) {
        await AppSession.instance.refreshEmsToken(force: true);
      }
      if (!mounted) return;
      if (!AppSession.instance.hasEms) {
        showErrorSnack(
          context,
          'Chưa kết nối được EMS. Chưa có dữ liệu điểm danh nào được gửi. '
          'Vui lòng kiểm tra mạng rồi thử lại.',
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const EmsAttendanceTeacherScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final subject = d['mhten']?.toString() ?? '';
    final room = d['phongten']?.toString() ?? '';
    final classCode = d['lmhma']?.toString() ?? '';
    final start = d['thoigianbd']?.toString() ?? '';
    final endRaw = d['thoigiankt'] as String? ?? '';
    final end = endRaw.length >= 16 ? endRaw.substring(11, 16) : '';
    final buoi = _buoiInfo(context, d['buoi']?.toString());
    final baonghiyn = d['baonghiyn'];
    final daBaoNghi = baonghiyn != null && baonghiyn != false && baonghiyn != 0;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.vd.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: context.vd.shadow, blurRadius: 6, offset: Offset(0, 3)),
          ],
          border: Border(left: BorderSide(
            color: daBaoNghi ? context.vd.inkFaint : buoi.color,
            width: 5,
          )),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Giờ
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(start,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: buoi.color)),
                      const SizedBox(height: 2),
                      Text(end,
                          style: TextStyle(
                              fontSize: 12, color: context.vd.inkFaint)),
                    ],
                  ),
            const SizedBox(width: 14),
            Container(width: 1, height: 40, color: context.vd.hairline),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(subject,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (daBaoNghi) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.vd.surfaceAlt,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_busy_outlined,
                                  size: 12, color: context.vd.inkMuted),
                              SizedBox(width: 4),
                              Text('Báo nghỉ',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: context.vd.inkMuted)),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: buoi.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(buoi.label,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: buoi.color)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.room,
                          size: 13, color: context.vd.primary),
                      const SizedBox(width: 4),
                      Text(room,
                          style: TextStyle(
                              fontSize: 12, color: context.vd.inkFaint)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.class_outlined,
                          size: 13, color: context.vd.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(classCode,
                            style: TextStyle(
                                fontSize: 12, color: context.vd.inkMuted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: context.vd.inkFaint, size: 20,
            ),
          ],
        ),
      ),

            // ── Expanded: nút điểm danh ──
            if (_expanded) ...[
              Divider(height: 1, color: context.vd.surfaceAlt),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _openAttendance,
                        icon: _loading
                            ? SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    color: context.vd.onPrimary, strokeWidth: 2))
                            : Icon(Icons.checklist_rounded,
                                color: context.vd.onPrimary, size: 18),
                        label: Text('Điểm danh bằng danh sách',
                            style: TextStyle(color: context.vd.onPrimary,
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.vd.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
