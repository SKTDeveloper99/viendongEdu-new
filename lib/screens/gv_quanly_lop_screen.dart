import 'package:flutter/material.dart';
import '../services/crm_teacher_api.dart';
import '../services/crm_session_guard.dart';
import '../services/ems_api_service.dart';
import '../models/crm_teacher_class.dart';
import '../components/skeleton.dart';

class _Semester {
  final int id;
  final String ma;
  final String ten;
  const _Semester({required this.id, required this.ma, required this.ten});
}

class GvQuanLyLopScreen extends StatefulWidget {
  const GvQuanLyLopScreen({super.key});

  @override
  State<GvQuanLyLopScreen> createState() => _GvQuanLyLopScreenState();
}

class _GvQuanLyLopScreenState extends State<GvQuanLyLopScreen> {
  List<_Semester> _semesters = [];
  _Semester? _selected;
  List<CrmTeacherClass> _lops = [];

  /// `lmhma` (mã lớp môn học, trùng `sectionCode`) → `lmhid` (id IMS đã đồng
  /// bộ vào CRM) — cần để dựng `session_key` cho EMS. Lấy từ
  /// `GET /me/schedule/semester` (endpoint DUY NHẤT của CRM còn trả trường
  /// này) cùng lúc với danh sách lớp, tránh một lượt gọi mạng thêm khi mở
  /// từng lớp.
  Map<String, String> _lmhIdByCode = {};

  bool _loadingHocKy = true;
  bool _loadingLops = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHocKy();
  }

  Future<void> _fetchHocKy() async {
    setState(() { _loadingHocKy = true; _error = null; });
    try {
      final data = await CrmTeacherApi.semesters();
      final sems = data
          .map((e) => _Semester(id: e.id, ma: e.ma, ten: e.ten))
          .toList()
        ..sort((a, b) => b.id.compareTo(a.id));
      if (!mounted) return;
      setState(() { _semesters = sems; _loadingHocKy = false; });
      if (sems.isNotEmpty) await _fetchLops(sems.first);
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (!mounted) return;
      setState(() { _loadingHocKy = false; _error = e.toString(); });
    }
  }

  Future<void> _fetchLops(_Semester sem) async {
    setState(() { _selected = sem; _loadingLops = true; _error = null; });
    try {
      final results = await Future.wait([
        CrmTeacherApi.classes(semester: sem.ma),
        CrmTeacherApi.scheduleForSemester(sem.ma),
      ]);
      if (!mounted) return;
      final classes = results[0] as List<CrmTeacherClass>;
      final slots = results[1] as List<CrmScheduleSlot>;
      setState(() {
        _lops = classes;
        _lmhIdByCode = {for (final s in slots) s.lmhMa: s.lmhId};
        _loadingLops = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (!mounted) return;
      setState(() { _loadingLops = false; _error = e.toString(); });
    }
  }

  void _retry() {
    if (_semesters.isEmpty) {
      _fetchHocKy();
    } else if (_selected != null) {
      _fetchLops(_selected!);
    } else {
      _fetchHocKy();
    }
  }

  void _showDetail(CrmTeacherClass lop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: _LopDetailSheet(lop: lop, lmhId: _lmhIdByCode[lop.sectionCode]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(top: false, child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Quản lý lớp',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (!_loadingHocKy && !_loadingLops && _lops.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_lops.length} lớp',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                if (!_loadingHocKy && _semesters.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_Semester>(
                        value: _selected,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        iconEnabledColor: const Color(0xFFE65100),
                        icon: const Icon(Icons.expand_more_rounded, size: 20),
                        isDense: true,
                        style: const TextStyle(color: Color(0xFF333333), fontSize: 13, fontWeight: FontWeight.w500),
                        selectedItemBuilder: (_) => _semesters.map((s) => Center(
                          child: Text(s.ten, style: const TextStyle(color: Color(0xFFE65100), fontSize: 13, fontWeight: FontWeight.w600)),
                        )).toList(),
                        items: _semesters.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.ten),
                        )).toList(),
                        onChanged: (s) { if (s != null) _fetchLops(s); },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: _loadingHocKy
                ? skeletonList()
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _retry,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE65100)),
                              child: const Text('Thử lại',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : _loadingLops
                        ? skeletonList()
                        : _lops.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.manage_accounts_outlined,
                                        size: 64, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text('Không có lớp',
                                        style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                itemCount: _lops.length,
                                itemBuilder: (ctx, i) => _LopCard(
                                  lop: _lops[i],
                                  onTap: () => _showDetail(_lops[i]),
                                ),
                              ),
          ),
        ],
      )),
    );
  }
}

// ── Lop Card ─────────────────────────────────────────
class _LopCard extends StatelessWidget {
  final CrmTeacherClass lop;
  final VoidCallback onTap;
  const _LopCard({required this.lop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mhten = lop.subjectName ?? '';
    final mhma = lop.subjectCode ?? '';
    final sotinchi = lop.credits ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mã - Tên
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                        children: [
                          TextSpan(
                            text: mhma,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE65100)),
                          ),
                          const TextSpan(text: ' · '),
                          TextSpan(
                            text: mhten,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lop.sectionCode,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF444444)),
                      softWrap: true,
                    ),
                    const SizedBox(height: 6),
                    // Footer: tín chỉ + sĩ số
                    Row(
                      children: [
                        if (sotinchi > 0) ...[
                          const Icon(Icons.school_outlined,
                              size: 13, color: Color(0xFF555555)),
                          const SizedBox(width: 4),
                          Text('$sotinchi tín chỉ',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF555555))),
                          const SizedBox(width: 12),
                        ],
                        const Icon(Icons.people_outline,
                            size: 13, color: Color(0xFF555555)),
                        const SizedBox(width: 4),
                        Text('${lop.enrolledStudents} SV',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF555555))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right,
                  color: Colors.grey, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detail Bottom Sheet ───────────────────────────────
class _LopDetailSheet extends StatefulWidget {
  final CrmTeacherClass lop;
  final String? lmhId;
  const _LopDetailSheet({required this.lop, required this.lmhId});

  @override
  State<_LopDetailSheet> createState() => _LopDetailSheetState();
}

class _LopDetailSheetState extends State<_LopDetailSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<CrmClassStudent> _hocViens = [];
  bool _loadingHV = false;
  String? _hvError;

  List<CrmAttendanceRow> _attendanceRows = [];
  List<_Buoi> _buoiHocs = [];
  List<_StudentAgg> _tongHops = [];
  bool _loadingDD = false;
  String? _ddError;
  int _ddSubTab = 0; // 0 = buổi học, 1 = tổng hợp

  /// session_key -> (có mặt, tổng dòng EMS). EMS là nguồn duy nhất cho số
  /// "có mặt" thật (xem CLAUDE.md "EMS write path"/"giao vien"), bảng
  /// `attendance` của CRM chỉ còn dùng để liệt kê BUỔI (ngày/giờ/phòng) và
  /// danh sách học viên của buổi đó.
  final Map<String, _EmsSessionCount> _emsCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _hocViens.isEmpty && !_loadingHV && _hvError == null) {
        _loadHocViens();
      }
      if (_tabController.index == 2 && _attendanceRows.isEmpty && !_loadingDD && _ddError == null) {
        _loadDiemDanh();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHocViens() async {
    setState(() { _loadingHV = true; _hvError = null; });
    try {
      final data = await CrmTeacherApi.classStudents(widget.lop.sectionId);
      if (mounted) {
        setState(() { _hocViens = data; _loadingHV = false; });
      }
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (mounted) setState(() { _loadingHV = false; _hvError = e.toString(); });
    }
  }

  Future<void> _loadDiemDanh() async {
    setState(() { _loadingDD = true; _ddError = null; });
    try {
      final rows = await CrmTeacherApi.classAttendance(widget.lop.sectionId);
      if (mounted) {
        setState(() {
          _attendanceRows = rows;
          _buoiHocs = _groupBySession(rows);
          _tongHops = _aggregateByStudent(rows);
          _loadingDD = false;
        });
      }
      await _loadEmsCounts();
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (mounted) setState(() { _loadingDD = false; _ddError = e.toString(); });
    }
  }

  static List<_Buoi> _groupBySession(List<CrmAttendanceRow> rows) {
    final Map<String, _Buoi> byId = {};
    for (final r in rows) {
      final b = byId.putIfAbsent(
        r.sessionId,
        () => _Buoi(
          sessionId: r.sessionId,
          date: r.date,
          startTime: r.startTime,
          endTime: r.endTime,
          room: r.room,
        ),
      );
      if (r.mssv != null && r.mssv!.isNotEmpty) {
        b.students.add(r);
      }
    }
    final list = byId.values.toList()
      ..sort((a, b) => (a.date ?? '').compareTo(b.date ?? ''));
    return list;
  }

  static List<_StudentAgg> _aggregateByStudent(List<CrmAttendanceRow> rows) {
    final Map<String, _StudentAgg> byMssv = {};
    for (final r in rows) {
      final mssv = r.mssv;
      if (mssv == null || mssv.isEmpty) continue;
      final agg = byMssv.putIfAbsent(
          mssv, () => _StudentAgg(mssv: mssv, fullName: r.fullName ?? ''));
      agg.total++;
      if (r.status == 'present') agg.present++;
    }
    final list = byMssv.values.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    return list;
  }

  String? _sessionKeyOf(_Buoi b) {
    final lmhId = widget.lmhId;
    if (lmhId == null || lmhId.isEmpty || b.date == null) return null;
    final ngay = b.date!.length >= 10 ? b.date!.substring(0, 10) : b.date!;
    return EmsApiService.sessionKeyFor(
      lmhId: lmhId,
      date: ngay,
      startTime: b.startTime ?? '',
    );
  }

  /// Chỉ hỏi EMS cho buổi đã tới ngày (buổi tương lai chưa thể có dấu), và
  /// chỉ khi biết được `lmhid` (session_key cần nó — xem [widget.lmhId]).
  Future<void> _loadEmsCounts() async {
    if (widget.lmhId == null) return;
    final today = _todayHcm();
    final due = _buoiHocs.where((b) {
      final ngay = b.date ?? '';
      return ngay.length >= 10 && ngay.substring(0, 10).compareTo(today) <= 0;
    }).toList();
    await Future.wait(due.map((b) async {
      final key = _sessionKeyOf(b);
      if (key == null) return;
      try {
        final marks = await EmsApiService.sessionMarks(key);
        final present = marks.values
            .where((v) => v == 'present' || v == 'late' || v == 'excused')
            .length;
        _emsCounts[key] = _EmsSessionCount(present: present, total: marks.length);
      } catch (_) {
        // Không có mạng / EMS lỗi: giữ nguyên, hàng sẽ ghi "chưa có trên EMS".
      }
    }));
    if (mounted) setState(() {});
  }

  static String _todayHcm() {
    final d = DateTime.now().toUtc().add(const Duration(hours: 7));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  void _showBuoiDetail(_Buoi buoi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: _BuoiDetailSheet(
          buoi: buoi,
          sessionKey: _sessionKeyOf(buoi),
        ),
      ),
    );
  }

  static String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return iso; }
  }

  static String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.contains('T')) {
      try {
        final dt = DateTime.parse(raw);
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final lop = widget.lop;
    final mhten = lop.subjectName ?? '';
    final mhma = lop.subjectCode ?? '';
    final sotinchi = lop.credits ?? 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mhten,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(mhma,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFE65100),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // TabBar
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFE65100),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFFE65100),
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Thông tin'),
              Tab(text: 'Danh sách'),
              Tab(text: 'Điểm danh'),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 1: Thông tin ──
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    _DetailRow(icon: Icons.class_outlined, label: 'Mã lớp', value: lop.sectionCode),
                    const SizedBox(height: 12),
                    if (sotinchi > 0) ...[
                      _DetailRow(icon: Icons.school_outlined, label: 'Tín chỉ', value: '$sotinchi TC'),
                      const SizedBox(height: 12),
                    ],
                    if ((lop.room ?? '').isNotEmpty) ...[
                      _DetailRow(icon: Icons.room_outlined, label: 'Phòng', value: lop.room!),
                      const SizedBox(height: 12),
                    ],
                    _DetailRow(
                        icon: Icons.people_outline,
                        label: 'Sĩ số',
                        value: '${lop.enrolledStudents} sinh viên'),
                    const SizedBox(height: 12),
                    if ((lop.ngayBatDau ?? '').isNotEmpty || (lop.ngayKetThuc ?? '').isNotEmpty) ...[
                      _DetailRow(
                        icon: Icons.date_range_outlined,
                        label: 'Thời gian',
                        value:
                            '${_fmtDate(lop.ngayBatDau)} – ${_fmtDate(lop.ngayKetThuc)}',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if ((lop.ngayThi ?? '').isNotEmpty)
                      _DetailRow(icon: Icons.event_note_outlined, label: 'Ngày thi', value: _fmtDate(lop.ngayThi)),
                    // Tỷ lệ điểm chuyên cần/giữa kỳ/cuối kỳ (bản IMS cũ có donut
                    // theo % trọng số) KHÔNG có tương đương trong CRM
                    // (`sections`/`subjects` không lưu trọng số điểm theo lớp) —
                    // bỏ thay vì bịa số. TODO(A4 hoặc bot điểm): thêm nếu/khi CRM
                    // có bảng trọng số điểm.
                  ],
                ),

                // ── Tab 2: Danh sách học viên ──
                _loadingHV
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                    : _hvError != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(_hvError!,
                                    style: const TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _loadHocViens,
                                  child: const Text('Thử lại',
                                      style: TextStyle(color: Color(0xFFE65100))),
                                ),
                              ],
                            ),
                          )
                        : _hocViens.isEmpty
                            ? const Center(
                                child: Text('Không có học viên',
                                    style: TextStyle(color: Colors.grey)),
                              )
                            : Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.people_outline,
                                          size: 15, color: Color(0xFFE65100)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Tổng: ${_hocViens.length} sinh viên',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFE65100)),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                                itemCount: _hocViens.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1, color: Color(0xFFF5F5F5)),
                                itemBuilder: (_, i) {
                                  final hv = _hocViens[i];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(0xFFE65100)
                                              .withValues(alpha: 0.1),
                                          child: Text(
                                            '${i + 1}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFE65100)),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(hv.fullName,
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600)),
                                              const SizedBox(height: 2),
                                              Text(hv.mssv,
                                                  style: const TextStyle(
                                                      fontSize: 12, color: Color(0xFF555555))),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                                ),
                              ],
                            ),

                // ── Tab 3: Điểm danh ──
                _loadingDD
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                    : _ddError != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(_ddError!,
                                    style: const TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _loadDiemDanh,
                                  child: const Text('Thử lại',
                                      style: TextStyle(color: Color(0xFFE65100))),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              if (widget.lmhId == null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Không xác định được buổi trên EMS cho lớp này — chỉ hiện dữ liệu ghi nhận trên CRM.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF795548)),
                                    ),
                                  ),
                                ),
                              // Sub-tab toggle
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      _SubTabBtn(
                                        label: 'Buổi học',
                                        selected: _ddSubTab == 0,
                                        onTap: () => setState(() => _ddSubTab = 0),
                                      ),
                                      _SubTabBtn(
                                        label: 'Tổng hợp',
                                        selected: _ddSubTab == 1,
                                        onTap: () => setState(() => _ddSubTab = 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: _ddSubTab == 0
                                    ? (_buoiHocs.isEmpty
                                        ? const Center(
                                            child: Text('Chưa có buổi điểm danh',
                                                style: TextStyle(color: Colors.grey)),
                                          )
                                        : ListView.separated(
                                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                                            itemCount: _buoiHocs.length,
                                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                                            itemBuilder: (_, i) {
                                              final b = _buoiHocs[i];
                                              final ngay = _fmtDate(b.date);
                                              final tbd = b.startTime ?? '';
                                              final tkt = _fmtTime(b.endTime);
                                              final siso = widget.lop.enrolledStudents;
                                              final key = _sessionKeyOf(b);
                                              final ems = key == null ? null : _emsCounts[key];
                                              final daDiemDanh = ems != null && ems.total > 0;
                                              final crmPresent = b.students
                                                  .where((s) => s.status == 'present')
                                                  .length;
                                              final hiendien = daDiemDanh ? ems.present : crmPresent;
                                              final pct = siso > 0 ? hiendien / siso : 0.0;
                                              final countText = daDiemDanh
                                                  ? '$hiendien / $siso có mặt (EMS)'
                                                  : crmPresent > 0
                                                      ? '$crmPresent / $siso có mặt trên CRM — chưa xác nhận trên EMS'
                                                      : '0 / $siso — chưa điểm danh';
                                              return GestureDetector(
                                              onTap: () => _showBuoiDetail(b),
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: const [
                                                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const Icon(Icons.calendar_today,
                                                                  size: 13, color: Color(0xFFE65100)),
                                                              const SizedBox(width: 5),
                                                              Text(ngay,
                                                                  style: const TextStyle(
                                                                      fontSize: 14,
                                                                      fontWeight: FontWeight.bold)),
                                                              const SizedBox(width: 8),
                                                              Text('$tbd – $tkt',
                                                                  style: const TextStyle(
                                                                      fontSize: 12, color: Color(0xFF555555))),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(countText,
                                                                    style: const TextStyle(
                                                                        fontSize: 13, color: Color(0xFF444444))),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 6),
                                                          ClipRRect(
                                                            borderRadius: BorderRadius.circular(4),
                                                            child: LinearProgressIndicator(
                                                              value: pct,
                                                              minHeight: 5,
                                                              backgroundColor: Colors.grey[200],
                                                              color: pct >= 0.8
                                                                  ? const Color(0xFF4CAF50)
                                                                  : pct >= 0.5
                                                                      ? const Color(0xFFFF9800)
                                                                      : Colors.red,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: daDiemDanh
                                                            ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                                                            : Colors.grey.withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        daDiemDanh ? 'Đã ĐD' : 'Chưa ĐD',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: daDiemDanh
                                                              ? const Color(0xFF4CAF50)
                                                              : Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ));
                                            },
                                          ))
                                    : (_tongHops.isEmpty
                                        ? const Center(
                                            child: Text('Chưa có dữ liệu',
                                                style: TextStyle(color: Colors.grey)),
                                          )
                                        : ListView.separated(
                                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                                            itemCount: _tongHops.length,
                                            separatorBuilder: (_, _) =>
                                                const Divider(height: 1, color: Color(0xFFF5F5F5)),
                                            itemBuilder: (_, i) {
                                              final t = _tongHops[i];
                                              final tongSo = t.total;
                                              final hiendien = t.present;
                                              final pct = tongSo > 0 ? hiendien / tongSo : 0.0;
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 18,
                                                      backgroundColor: const Color(0xFFE65100)
                                                          .withValues(alpha: 0.1),
                                                      child: Text('${i + 1}',
                                                          style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                              color: Color(0xFFE65100))),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(t.fullName,
                                                              style: const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight: FontWeight.w600)),
                                                          const SizedBox(height: 2),
                                                          Text(t.mssv,
                                                              style: const TextStyle(
                                                                  fontSize: 12, color: Colors.grey)),
                                                          const SizedBox(height: 4),
                                                          ClipRRect(
                                                            borderRadius: BorderRadius.circular(4),
                                                            child: LinearProgressIndicator(
                                                              value: pct,
                                                              minHeight: 4,
                                                              backgroundColor: Colors.grey[200],
                                                              color: pct >= 0.8
                                                                  ? const Color(0xFF4CAF50)
                                                                  : pct >= 0.5
                                                                      ? const Color(0xFFFF9800)
                                                                      : Colors.red,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text('$hiendien/$tongSo',
                                                        style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFFE65100))),
                                                  ],
                                                ),
                                              );
                                            },
                                          )),
                              ),
                            ],
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFFE65100)),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              softWrap: true),
        ),
      ],
    );
  }
}

// ── Buổi Detail Sheet ────────────────────────────────
class _BuoiDetailSheet extends StatefulWidget {
  final _Buoi buoi;
  final String? sessionKey;
  const _BuoiDetailSheet({required this.buoi, required this.sessionKey});

  @override
  State<_BuoiDetailSheet> createState() => _BuoiDetailSheetState();
}

class _BuoiDetailSheetState extends State<_BuoiDetailSheet> {
  List<CrmAttendanceRow> _students = [];
  Map<String, String> _emsStatus = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Danh sách học viên của buổi: CRM (`attendance` join `sessions`), đã
      // tải sẵn ở màn hình cha (widget.buoi.students). Có mặt/vắng THẬT: EMS
      // (session-marks) — không dùng trạng thái `attendance` của CRM nữa,
      // giống hệt quy định 2026-09-09 khi còn IMS.
      final key = widget.sessionKey;
      final ems = key == null
          ? <String, String>{}
          : await EmsApiService.sessionMarks(key);
      if (mounted) {
        setState(() {
          _students = widget.buoi.students;
          _emsStatus = ems;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  static String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.contains('T')) {
      try {
        final dt = DateTime.parse(raw);
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return raw;
  }

  bool? _presentOf(CrmAttendanceRow s) {
    final st = _emsStatus[s.mssv ?? ''];
    if (st == null) return null; // chưa điểm danh trên EMS
    return st == 'present' || st == 'late' || st == 'excused';
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.buoi;
    final ngay = _LopDetailSheetState._fmtDate(b.date);
    final tbd = b.startTime ?? '';
    final tkt = _fmtTime(b.endTime);

    final present = _students.where((s) => _presentOf(s) == true).length;
    final absent = _students.where((s) => _presentOf(s) == false).length;
    final unmarked = _students.length - present - absent;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ngay,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('$tbd – $tkt',
                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                if (!_loading && _error == null) ...[
                  _StatPill(label: 'Có mặt', value: present, color: const Color(0xFF4CAF50)),
                  const SizedBox(width: 8),
                  _StatPill(label: 'Vắng', value: absent, color: Colors.red),
                  _StatPill(label: 'Chưa ĐD', value: unmarked, color: const Color(0xFF2196F3)),
                ] else ...[
                  Text('Sĩ số: ${_students.length}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: const TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Thử lại',
                                  style: TextStyle(color: Color(0xFFE65100))),
                            ),
                          ],
                        ),
                      )
                    : _students.isEmpty
                        ? const Center(
                            child: Text('Không có học viên',
                                style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: _students.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Color(0xFFF5F5F5)),
                        itemBuilder: (_, i) {
                          final s = _students[i];
                          final fullName = s.fullName ?? '';
                          final mshv = s.mssv ?? '';
                          final presentState = _presentOf(s);
                          final unmarked = presentState == null;
                          final tone = unmarked
                              ? const Color(0xFF2196F3)
                              : presentState
                                  ? const Color(0xFF4CAF50)
                                  : Colors.red;
                          final label = unmarked
                              ? 'Chưa điểm danh'
                              : presentState
                                  ? 'Có mặt'
                                  : 'Vắng';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: tone.withValues(alpha: 0.1),
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: tone)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(fullName,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(mshv,
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: tone.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: tone,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(width: 4),
          Text('$value',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _SubTabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SubTabBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE65100) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

/// Một buổi học, dựng bằng cách gộp các dòng phẳng của
/// `GET /me/classes/:id/attendance` theo `session_id`.
class _Buoi {
  final String sessionId;
  final String? date;
  final String? startTime;
  final String? endTime;
  final String? room;
  final List<CrmAttendanceRow> students = [];

  _Buoi({
    required this.sessionId,
    this.date,
    this.startTime,
    this.endTime,
    this.room,
  });
}

/// Tổng hợp điểm danh của một học viên trong lớp, gộp từ các dòng
/// `attendance` của CRM (KHÔNG phải EMS — xem ghi chú ở [CrmAttendanceRow]).
class _StudentAgg {
  final String mssv;
  final String fullName;
  int total = 0;
  int present = 0;
  _StudentAgg({required this.mssv, required this.fullName});
}

class _EmsSessionCount {
  final int present;
  final int total;
  const _EmsSessionCount({required this.present, required this.total});
}
