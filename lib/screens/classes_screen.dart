import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/crm_student_exams.dart' show semesterCodeLabel;
import '../models/crm_student_grades.dart';
import '../models/crm_student_schedule.dart';
import '../services/crm_student_api.dart';
import '../services/ems_api_service.dart';
import '../components/skeleton.dart';

// ── Model ──────────────────────────────────────────────
//
// CRM has no dedicated "danh sách học kỳ" endpoint for students (only
// GET /api/teacher/me/semesters exists, teacher-only — verified by reading
// routes/portals/teacher-portal.js and routes/portals/student-portal.js).
// The list here is DERIVED from the distinct semester_code values seen in
// /api/student/me/sections, exactly as documented in
// docs/ims_to_crm_student_academic_map.md.
class _Semester {
  final String code;
  final String ten;
  const _Semester({required this.code, required this.ten});
}

// ── Class item ───────────────────────────────────────────
// CRM /me/sections has no per-class evaluation weights (tylecc/tylegk/tyleck)
// or syllabus text (decuong) — those were already dead fields in the old
// screen (see docs/ims_to_crm_student_academic_map.md) and are not modelled
// here. Score breakdown (diemcc/diemgk/diemck/tongdiem) is filled in
// separately from /me/grades, matched by section_code — see
// _ClassesScreenState._selectSemester.
class _LopItem {
  final int? sectionId;
  final String lmhma; // section_code
  final String mhma; // subject_code
  final String mhten; // subject_name
  final int sotinchi; // credits
  final String gvten; // teacher_name
  double? tongdiem;
  double? diemgk; // midterm_score
  double? diemck; // final_exam_score

  _LopItem({
    required this.sectionId,
    required this.lmhma,
    required this.mhma,
    required this.mhten,
    required this.sotinchi,
    required this.gvten,
  });

  factory _LopItem.fromSection(CrmStudentSection s) => _LopItem(
    sectionId: s.sectionId,
    lmhma: s.sectionCode,
    mhma: s.subjectCode,
    mhten: s.subjectName,
    sotinchi: s.credits,
    gvten: s.teacherName,
  );

  // CRM không có điểm "chuyên cần" (diemcc) riêng — chỉ midterm/final.
  double? get diemcc => null;
}

// ── Screen ─────────────────────────────────────────────
class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  List<_Semester> _semesters = [];
  List<_LopItem> _classes = [];
  _Semester? _selected;
  bool _loading = true;
  bool _loadingClasses = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSemesters();
  }

  Future<void> _fetchSemesters() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Không lọc theo semester để lấy đủ lịch sử ghi danh, rồi rút ra danh
      // sách học kỳ duy nhất từ đó — xem ghi chú ở lớp _Semester.
      final sections = await CrmStudentApi.sections();
      final seen = <String>{};
      final sems = <_Semester>[];
      for (final s in sections) {
        final code = s.semesterCode;
        if (code == null || code.isEmpty || !seen.add(code)) continue;
        sems.add(_Semester(code: code, ten: semesterCodeLabel(code)));
      }
      // Mới nhất trước (mã học kỳ lớn hơn = mới hơn).
      sems.sort((a, b) => b.code.compareTo(a.code));
      if (!mounted) return;
      setState(() {
        _semesters = sems;
        _loading = false;
      });
      if (sems.isNotEmpty) _selectSemester(sems.first);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _selectSemester(_Semester sem) async {
    setState(() { _selected = sem; _loadingClasses = true; _classes = []; });
    try {
      final results = await Future.wait([
        CrmStudentApi.sections(semester: sem.code),
        CrmStudentApi.grades(),
      ]);
      if (!mounted) return;
      final sections = results[0] as List<CrmStudentSection>;
      final grades = (results[1] as CrmStudentGradesView).grades;
      final items = sections.map(_LopItem.fromSection).toList();
      // Gắn điểm giữa/cuối kỳ từ /me/grades, khớp theo section_code (rồi rơi
      // về subject_code + học kỳ khi một dòng điểm không có section_code —
      // xảy ra với ~2.900 dòng điểm nhập tay không có LMH đứng sau, theo ADR
      // 004 trong crm-clean).
      for (final item in items) {
        CrmStudentGrade? g = grades.cast<CrmStudentGrade?>().firstWhere(
          (g) => g?.sectionCode == item.lmhma,
          orElse: () => null,
        );
        g ??= grades.cast<CrmStudentGrade?>().firstWhere(
          (g) =>
              g?.subjectCode == item.mhma && g?.semesterCode == sem.code,
          orElse: () => null,
        );
        if (g != null) {
          item.tongdiem = g.finalScore;
          item.diemgk = g.midtermScore;
          item.diemck = g.finalExamScore;
        }
      }
      setState(() {
        _classes = items;
        _loadingClasses = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingClasses = false; });
    }
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
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Lớp học',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Text(
                //   'MSSV: ${AppSession.instance.hocVien?.mshv ?? ''}',
                //   style: const TextStyle(color: Colors.white70, fontSize: 13),
                // ),
                const SizedBox(height: 16),
                if (!_loading && _semesters.isNotEmpty)
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
                        onChanged: (s) { if (s != null) _selectSemester(s); },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: _loading
                ? skeletonList(accentColor: Color(0xFFE65100))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchSemesters,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFE65100)),
                              child: const Text('Thử lại',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : _loadingClasses
                        ? skeletonList(accentColor: Color(0xFFE65100))
                        : _classes.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.school_outlined,
                                        size: 64, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text('Không có lớp học',
                                        style:
                                            TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 14, 16, 4),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${_classes.length} lớp học',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: RefreshIndicator(
                                      onRefresh: () => _selectSemester(_selected!),
                                      color: const Color(0xFFE65100),
                                      child: ListView.builder(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 4, 16, 24),
                                      itemCount: _classes.length,
                                      itemBuilder: (context, i) =>
                                          _ClassCard(
                                        item: _classes[i],
                                        semTen: _selected?.ten ?? '',
                                      ),
                                    ),
                                    ),
                                  ),
                                ],
                              ),
          ),
        ],
      )),
    );
  }
}

// ── Class Card ─────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final _LopItem item;
  final String semTen;
  const _ClassCard({required this.item, required this.semTen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                _ClassDetailScreen(item: item, semTen: semTen)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 96,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(16)),
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
                            item.mhten,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (item.sotinchi > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  Color(0xFFE65100).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${item.sotinchi} TC',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE65100)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 13, color: Color(0xFFE65100)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(item.gvten,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.tag,
                            size: 13, color: Color(0xFFE65100)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(item.lmhma,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
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

// ── Detail Screen ──────────────────────────────────────
class _ClassDetailScreen extends StatefulWidget {
  final _LopItem item;
  final String semTen;
  const _ClassDetailScreen({required this.item, required this.semTen});

  @override
  State<_ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<_ClassDetailScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchBuoiHoc();
  }

  // Điểm danh giờ đọc từ EMS, KHÔNG còn từ IMS. EMS là nguồn chính thức: một
  // buổi chỉ có mặt trong danh sách khi giáo viên đã ghi nhận trên EMS.
  //
  // Trước đây lọc theo tiền tố `lmhid:` của IMS (một khoá nội bộ của
  // ims_snapshot). CRM không cấp lmhid cho học viên nữa, nên lọc trực tiếp
  // theo `section_code` — chính là `EmsStudentMark.sectionCode`, nguồn thật
  // của EMS cho lớp này. Giữ nguyên khung dữ liệu cũ (ngay / hiendienyn /
  // baonghiyn) để tái dùng y hệt biểu đồ và danh sách buổi học sẵn có.
  Future<void> _fetchBuoiHoc() async {
    try {
      final marks = await EmsApiService.myAttendance(limit: 300);
      if (!mounted) return;
      final sessions = marks
          .where((m) => m.sectionCode == widget.item.lmhma)
          .map((m) {
            final st = m.status;
            return <String, dynamic>{
              // date-only để tránh lệch ngày khi parse mốc UTC nửa đêm
              'ngay': (m.sessionDate ?? '').split('T').first,
              'hiendienyn': (st == 'present' || st == 'late')
                  ? true
                  : (st == 'absent' ? false : null),
              'baonghiyn': st == 'excused',
            };
          })
          .toList()
        ..sort((a, b) {
          final da = DateTime.tryParse(a['ngay'] as String? ?? '') ?? DateTime(0);
          final db = DateTime.tryParse(b['ngay'] as String? ?? '') ?? DateTime(0);
          return da.compareTo(db);
        });
      setState(() { _sessions = sessions; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _present => _sessions.where((s) => s['hiendienyn'] == true).length;
  int get _absent  => _sessions.where((s) => s['hiendienyn'] == false).length;
  int get _pending => _sessions.where((s) => s['hiendienyn'] == null).length;

  bool get _hasGrades =>
      widget.item.tongdiem != null ||
      widget.item.diemcc != null ||
      widget.item.diemgk != null ||
      widget.item.diemck != null;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(top: false, child: Column(
        children: [
          // Header
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
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(height: 10),
                Text(item.mhten,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(widget.semTen,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE65100)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _infoCard(item),
                        const SizedBox(height: 16),
                        if (_hasGrades) ...[
                          _gradeCard(item),
                          const SizedBox(height: 16),
                        ],
                        if (_sessions.isNotEmpty) ...[
                          _attendanceCard(),
                          const SizedBox(height: 16),
                          _sessionListCard(),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      )),
    );
  }

  Widget _infoCard(_LopItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _Row(Icons.tag, 'Mã lớp', item.lmhma),
          _divider(),
          _Row(Icons.book_outlined, 'Mã môn', item.mhma),
          _divider(),
          _Row(Icons.school_outlined, 'Tín chỉ', '${item.sotinchi} TC'),
          _divider(),
          _Row(Icons.person_outline, 'Giảng viên', item.gvten),
        ],
      ),
    );
  }

  Widget _gradeCard(_LopItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Điểm số',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              if (item.diemcc != null)
                Expanded(child: _ScoreBox('Chuyên cần', item.diemcc!)),
              if (item.diemgk != null) ...[
                const SizedBox(width: 10),
                Expanded(child: _ScoreBox('Giữa kỳ', item.diemgk!)),
              ],
              if (item.diemck != null) ...[
                const SizedBox(width: 10),
                Expanded(child: _ScoreBox('Cuối kỳ', item.diemck!)),
              ],
            ],
          ),
          if (item.tongdiem != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('Tổng kết',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const Spacer(),
                  Text(item.tongdiem!.toStringAsFixed(1),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _attendanceCard() {
    final total = _sessions.length;
    final pct = total > 0 ? (_present / total * 100).round() : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thống kê điểm danh',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              // Donut chart
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        startDegreeOffset: -90,
                        sections: [
                          if (_present > 0)
                            PieChartSectionData(
                              value: _present.toDouble(),
                              color: const Color(0xFF4CAF50),
                              radius: 28,
                              showTitle: false,
                            ),
                          if (_absent > 0)
                            PieChartSectionData(
                              value: _absent.toDouble(),
                              color: const Color(0xFFF44336),
                              radius: 28,
                              showTitle: false,
                            ),
                          if (_pending > 0)
                            PieChartSectionData(
                              value: _pending.toDouble(),
                              color: const Color(0xFFBDBDBD),
                              radius: 28,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$pct%',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const Text('có mặt',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendRow(const Color(0xFF4CAF50), 'Có mặt', _present, total),
                    const SizedBox(height: 10),
                    _LegendRow(const Color(0xFFF44336), 'Vắng mặt', _absent, total),
                    const SizedBox(height: 10),
                    _LegendRow(const Color(0xFFBDBDBD), 'Chưa điểm danh', _pending, total),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.layers_outlined,
                            size: 15, color: Color(0xFFE65100)),
                        const SizedBox(width: 6),
                        Text('Tổng: $total buổi',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sessionListCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chi tiết các buổi học',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._sessions.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            final ngay = DateTime.tryParse(s['ngay'] as String? ?? '');
            final dateStr = ngay != null
                ? '${ngay.day.toString().padLeft(2, '0')}/${ngay.month.toString().padLeft(2, '0')}/${ngay.year}'
                : '';
            //final start = s['thoigianbd'] as String? ?? '';
            final hiendien = s['hiendienyn'];
            final baonghi = s['baonghiyn'];

            final (label, color, bg, icon) = hiendien == true
                ? ('Có mặt', const Color(0xFF4CAF50), const Color(0xFFE8F5E9), Icons.check_circle_outline)
                : hiendien == false
                    ? ('Vắng mặt', const Color(0xFFF44336), const Color(0xFFFFEBEE), Icons.cancel_outlined)
                    : baonghi == true
                        ? ('Báo nghỉ', Color(0xFFE65100), const Color(0xFFFFF3E0), Icons.event_busy_outlined)
                        : ('Chưa điểm danh', const Color(0xFF9E9E9E), const Color(0xFFF5F5F5), Icons.radio_button_unchecked);

            return Column(
              children: [
                if (i > 0) const Divider(height: 1, color: Color(0xFFF0F0F0)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Buổi ${i + 1}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 12, color: Color(0xFFE65100)),
                                const SizedBox(width: 4),
                                Text(dateStr,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 12, color: color),
                            const SizedBox(width: 4),
                            Text(label,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: color)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
      height: 1, indent: 48, endIndent: 16, color: Color(0xFFF0F0F0));
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int total;
  const _LegendRow(this.color, this.label, this.count, this.total);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Row(
      children: [
        Container(
          width: 11, height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        Text('$count  ($pct%)',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final double value;
  const _ScoreBox(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value % 1 == 0
                ? value.toInt().toString()
                : value.toString(),
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
