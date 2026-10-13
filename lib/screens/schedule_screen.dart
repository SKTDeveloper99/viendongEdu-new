import 'stale_note.dart';
import 'package:flutter/material.dart';
import '../models/crm_student_schedule.dart';
import '../services/app_session.dart';
import '../services/crm_student_api.dart';
import '../services/ems_api_service.dart';
import '../data/api/attendance_api.dart';
import '../theme/vd_tokens.dart';
import '../components/student_schedule_header.dart';
import '../components/student_schedule_card.dart';
import '../components/unscheduled_subjects.dart';

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _currentMonday;
  late DateTime _selectedDate;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  // CRM /me/schedule không có API theo-ngày như IMS `hocvien/tkbtheongay`:
  // nó trả TOÀN BỘ lịch học lặp-hàng-tuần của mọi học kỳ đã ghi danh trong
  // một lần gọi (xem lib/models/crm_student_schedule.dart). Tải một lần rồi
  // lọc theo ngày ở client (CrmScheduleItem.occursOn), và giữ cache theo
  // ngày để build() không lọc lại mỗi lần.
  List<CrmScheduleItem>? _fullSchedule;
  List<CrmUnscheduledSection> _chuaCoLich = const [];
  bool _scheduleFailed = false;
  final Map<String, List<CrmScheduleItem>> _cache = {};
  bool _loading = false;
  DateTime? _staleAt;

  // ── Trạng thái điểm danh: CHỈ đọc từ EMS ─────────────────────────────────
  // Trước 2026-09-11 huy hiệu trên thẻ lấy `hienDienYN` của IMS. Từ khi giáo
  // viên điểm danh trên EMS, IMS không còn là nơi ghi nhận: một sinh viên bị
  // đánh VẮNG trên EMS vẫn hiện "Có mặt" ở đây vì IMS còn giữ dòng cũ. Lịch
  // (giờ, phòng, giáo viên) vẫn là IMS; trạng thái là EMS — hai nguồn, không
  // trộn. Khoá: mã lớp môn học + ngày (+ giờ bắt đầu nếu EMS có).
  final Map<String, EmsStudentMark> _emsByKey = {};
  bool _emsLoaded = false;

  static String _markKey(String sectionCode, String date, [String? hhmm]) =>
      '$sectionCode|$date|${hhmm ?? ''}';

  Future<void> _loadEmsMarks({bool force = false}) async {
    if (_emsLoaded && !force) return;
    // 2026-09-11: a student (2652092061) was marked VẮNG on EMS but saw "Chưa
    // điểm danh". The mirror at login had timed out on the phone (IMS edge
    // 302-ing) while the server finished it later, so this screen opened with
    // no EMS token, skipped silently, and never asked again. Never skip
    // silently: without a token, ask for one here; on failure the cards show
    // "Chưa điểm danh" and pull-to-refresh tries the whole thing again.
    if (!AppSession.instance.hasEms) {
      await AppSession.instance.refreshEmsToken(force: force);
      if (!mounted || !AppSession.instance.hasEms) return;
    }
    try {
      final marks = await AttendanceApi.myAttendance(limit: 400);
      if (!mounted) return;
      setState(() {
        _emsByKey.clear();
        for (final m in marks) {
          final code = m.sectionCode ?? '';
          final date = m.sessionDate ?? '';
          if (code.isEmpty || date.isEmpty) continue;
          final hhmm = _startFromSessionKey(m.sessionKey) ?? m.startTime;
          // EMS thắng IMS cho cùng một buổi; không bao giờ ngược lại.
          void put(String k) {
            final cur = _emsByKey[k];
            if (cur == null || (cur.source != 'ems' && m.source == 'ems')) {
              _emsByKey[k] = m;
            }
          }

          put(_markKey(code, date));
          if (hhmm != null) put(_markKey(code, date, hhmm));
        }
        _emsLoaded = true;
      });
    } catch (_) {
      // EMS chết thì thẻ hiện "Chưa điểm danh" — không bao giờ rơi về IMS.
    }
  }

  /// `43371:07-30:2026-09-11` → `07:30`. Khoá IMS (`ims:<id>`) → null.
  static String? _startFromSessionKey(String? key) {
    if (key == null) return null;
    final parts = key.split(':');
    if (parts.length < 3) return null;
    final m = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(parts[1]);
    return m == null ? null : '${m.group(1)}:${m.group(2)}';
  }

  String _statusFor(CrmScheduleItem data, String date) {
    final code = data.sectionCode;
    final start = (data.startTime ?? '').trim();
    final hhmm = start.length >= 5 ? start.substring(0, 5) : null;
    final m =
        (hhmm != null ? _emsByKey[_markKey(code, date, hhmm)] : null) ??
        _emsByKey[_markKey(code, date)];
    if (m?.status != null) {
      return switch (m!.status) {
        'present' || 'late' => 'present',
        'absent' => 'absent',
        'excused' => 'excused',
        _ => 'pending',
      };
    }
    // IMS's schedule row carried its own `baonghiyn` (báo nghỉ) flag as a
    // fallback when no EMS mark existed yet; CRM's /me/schedule has no such
    // per-row flag (that concept never migrated — see
    // docs/ims_to_crm_student_academic_map.md). Falls back to "pending".
    return 'pending';
  }

  final ScrollController _chipScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = _now();
    _currentMonday = _findMonday(now);
    _selectedDate = now;
    _fetchDate(now);
    _loadEmsMarks();
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
    int index = weekDays.indexWhere(
      (d) => _fmtDate(d) == _fmtDate(_selectedDate),
    );
    if (index == -1) return;
    const chipWidth = 60.0;
    const chipMargin = 8.0;
    final chipOffset = index * (chipWidth + chipMargin);
    final viewport = _chipScroll.position.viewportDimension;
    final center = (chipOffset - viewport / 2 + chipWidth / 2).clamp(
      0.0,
      _chipScroll.position.maxScrollExtent,
    );
    _chipScroll.animateTo(
      center,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  DateTime _findMonday(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _currentMonday.add(Duration(days: i)));

  Future<void> _fetchDate(DateTime date) async {
    final key = _fmtDate(date);
    if (_cache.containsKey(key)) return; // đã có cache

    setState(() {
      _loading = true;
      _scheduleFailed = false;
    });
    try {
      if (_fullSchedule == null) {
        final r = await CrmStudentApi.scheduleViewCached();
        if (!mounted) return;
        _fullSchedule = r.data.schedule;
        _chuaCoLich = r.data.chuaCoLich;
        _staleAt = r.fresh ? null : r.savedAt;
      }
      if (!mounted) return;
      setState(() {
        _cache[key] = _fullSchedule!.where((s) => s.occursOn(date)).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scheduleFailed = true;
        _chuaCoLich = const [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _fetchDate(date);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _prevWeek() {
    setState(() {
      _currentMonday = _currentMonday.subtract(const Duration(days: 7));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _nextWeek() {
    setState(() {
      _currentMonday = _currentMonday.add(const Duration(days: 7));
    });
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
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: context.vd.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _currentMonday = _findMonday(picked);
      });
      _fetchDate(picked);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _weekDays;
    final start = _currentMonday;
    final end = _currentMonday.add(const Duration(days: 6));
    final weekLabel =
        '${start.day}/${start.month} – ${end.day}/${end.month}/${end.year}';
    final key = _fmtDate(_selectedDate);
    final classes = _cache[key];

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
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            StudentScheduleHeader(
              weekDays: weekDays,
              weekLabel: weekLabel,
              selectedDate: _selectedDate,
              today: _now(),
              chipScroll: _chipScroll,
              onPrevWeek: _prevWeek,
              onNextWeek: _nextWeek,
              onSelectDate: _selectDate,
            ),

            if (_staleAt != null) StaleNote(_staleAt!),
            // ── Content ──
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.vd.primary,
                      ),
                    )
                  : _scheduleFailed
                  ? Center(
                      child: Text(
                        'Đang đối chiếu',
                        style: TextStyle(color: context.vd.inkMuted),
                      ),
                    )
                  : classes == null
                  ? const SizedBox.shrink()
                  : classes.isEmpty && _chuaCoLich.isEmpty
                  ? Center(child: _emptyDay(context))
                  : RefreshIndicator(
                      color: context.vd.primary,
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          if (classes.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: _emptyDay(context),
                            ),
                          for (final data in classes)
                            StudentScheduleCard(
                              data: data,
                              status: _statusFor(data, key),
                            ),
                          if (_chuaCoLich.isNotEmpty)
                            UnscheduledSubjects(sections: _chuaCoLich),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    _cache.clear();
    _fullSchedule = null;
    await Future.wait([_fetchDate(_selectedDate), _loadEmsMarks(force: true)]);
  }

  Widget _emptyDay(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.event_available, size: 64, color: context.vd.inkFaint),
      const SizedBox(height: 12),
      Text('Không có lịch học', style: TextStyle(color: context.vd.inkFaint)),
    ],
  );
}
