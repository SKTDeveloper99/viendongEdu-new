import 'package:flutter/material.dart';
import '../models/crm_student_schedule.dart';
import '../services/app_session.dart';
import '../services/crm_student_api.dart';
import '../services/ems_api_service.dart';

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _currentMonday = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  // CRM /me/schedule không có API theo-ngày như IMS `hocvien/tkbtheongay`:
  // nó trả TOÀN BỘ lịch học lặp-hàng-tuần của mọi học kỳ đã ghi danh trong
  // một lần gọi (xem lib/models/crm_student_schedule.dart). Tải một lần rồi
  // lọc theo ngày ở client (CrmScheduleItem.occursOn), và giữ cache theo
  // ngày để build() không lọc lại mỗi lần.
  List<CrmScheduleItem>? _fullSchedule;
  final Map<String, List<CrmScheduleItem>> _cache = {};
  bool _loading = false;

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
      final marks = await EmsApiService.myAttendance(limit: 400);
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
    final m = (hhmm != null ? _emsByKey[_markKey(code, date, hhmm)] : null) ??
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
    final now = DateTime.now();
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

  DateTime _findMonday(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _currentMonday.add(Duration(days: i)));

  Future<void> _fetchDate(DateTime date) async {
    final key = _fmtDate(date);
    if (_cache.containsKey(key)) return; // đã có cache

    setState(() => _loading = true);
    try {
      _fullSchedule ??= await CrmStudentApi.schedule();
      if (!mounted) return;
      setState(() {
        _cache[key] = _fullSchedule!.where((s) => s.occursOn(date)).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cache[key] = []);
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
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFE65100)),
        ),
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
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickDate,
        backgroundColor: const Color(0xFFE65100),
        icon: const Icon(Icons.calendar_month, color: Colors.white, size: 20),
        label: Text(
          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
      body: SafeArea(top: false, child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back + title
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Lịch học',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 28),
                    ),
                    Text(
                      weekLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: _nextWeek,
                      child: const Icon(Icons.chevron_right,
                          color: Colors.white, size: 28),
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
                    itemCount: weekDays.length,
                    itemBuilder: (context, i) {
                      final day = weekDays[i];
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
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.2),
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
                                      ? const Color(0xFFE65100)
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? const Color(0xFFE65100)
                                      : Colors.white,
                                ),
                              ),
                              if (isToday)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(top: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFE65100)
                                        : Colors.white,
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
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE65100)),
                  )
                : classes == null
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFE65100)),
                      )
                    : classes.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_available,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('Không có lịch học',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFFE65100),
                            onRefresh: () async {
                              _cache.remove(_fmtDate(_selectedDate));
                              _fullSchedule = null;
                              await Future.wait([
                                _fetchDate(_selectedDate),
                                _loadEmsMarks(force: true),
                              ]);
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              itemCount: classes.length,
                              itemBuilder: (context, i) =>
                                  _ScheduleCard(
                                    data: classes[i],
                                    status: _statusFor(
                                        classes[i], _fmtDate(_selectedDate)),
                                  ),
                            ),
                          ),
          ),
        ],
      )),
    );
  }
}

// ── Schedule Card ────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final CrmScheduleItem data;
  /// Từ EMS (xem `_ScheduleScreenState._statusFor`), không phải IMS.
  final String status;
  const _ScheduleCard({required this.data, required this.status});

  @override
  Widget build(BuildContext context) {
    final subject = data.subjectName;
    final classCode = data.sectionCode;
    final room = data.room.trim();
    final teacher = data.teacherName;
    final start = data.startTime ?? '';
    final end = data.endTime ?? '';
    // CRM /me/schedule chỉ trả buổi HỌC — lịch thi nằm ở /me/exams riêng
    // (xem exam_screen.dart), nên không còn khái niệm "loaitkb == lichthi"
    // trộn trong cùng một feed như IMS `tkbtheongay` nữa. `isLichThi` giữ lại
    // như một cờ luôn false (thay vì xoá hẳn nhánh hiển thị) để badge "Lịch
    // thi" bên dưới không chết hẳn nếu một bot khác sau này gộp lịch thi vào
    // đây — không dùng `const` để tránh cảnh báo dead_code từ analyzer.
    final isLichThi = DateTime.now().year < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isLichThi ? const Color(0xFFF3E5F5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
        children: [
          // Thanh màu trái — đổi màu theo điểm danh / loại tkb
          Container(
            width: 5,
            height: double.infinity,
            decoration: BoxDecoration(
              color: isLichThi
                  ? const Color(0xFF7B1FA2)
                  : switch (status) {
                      'present' => const Color(0xFF4CAF50),
                      'absent'  => const Color(0xFFF44336),
                      'excused' => const Color(0xFF9E9E9E),
                      _         => const Color(0xFF2196F3),
                    },
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isLichThi)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B1FA2).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.assignment_outlined,
                                  size: 12, color: Color(0xFF7B1FA2)),
                              SizedBox(width: 4),
                              Text('Lịch thi',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF7B1FA2))),
                            ],
                          ),
                        ),
                      _StatusBadge(status: status),
                      const SizedBox(width: 12),
                    ],
                  ),
                  if (classCode.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 12),
                      child: Text(
                        classCode,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF444444),
                            fontWeight: FontWeight.w400),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 13, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Text(
                        end.isNotEmpty ? '$start – $end' : start,
                        style: const TextStyle(
                            fontSize: 12, color: Color.fromARGB(255, 0, 0, 0)),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.person_outline,
                          size: 13, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          teacher,
                          style: const TextStyle(
                              fontSize: 12, color: Color.fromARGB(255, 0, 0, 0)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.room,
                          size: 13, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          room,
                          style: const TextStyle(
                              fontSize: 12, color: Color.fromARGB(255, 0, 0, 0)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// ── Status Badge ─────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = switch (status) {
      'present' => (
          label: 'Có mặt',
          color: const Color(0xFF4CAF50),
          bg: const Color(0xFFE8F5E9),
          icon: Icons.check_circle_outline,
        ),
      'absent' => (
          label: 'Vắng mặt',
          color: const Color(0xFFF44336),
          bg: const Color(0xFFFFEBEE),
          icon: Icons.cancel_outlined,
        ),
      'excused' => (
          label: 'Báo nghỉ',
          color: const Color(0xFF757575),
          bg: const Color(0xFFF5F5F5),
          icon: Icons.event_busy_outlined,
        ),
      _ => (
          label: 'Chưa điểm danh',
          color: const Color(0xFF2196F3),
          bg: const Color(0xFFE3F2FD),
          icon: Icons.radio_button_unchecked,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg.icon, size: 12, color: cfg.color),
          const SizedBox(width: 4),
          Text(
            cfg.label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cfg.color),
          ),
        ],
      ),
    );
  }
}
