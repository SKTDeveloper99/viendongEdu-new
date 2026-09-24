import 'package:flutter/material.dart';
import '../models/crm_student_exams.dart';
import '../services/crm_student_api.dart';

// ── Model ────────────────────────────────────────────────
//
// Wraps CrmStudentExam (GET /api/student/me/exams — see
// docs/api/mobile-ims-replacement-S3.md in crm-clean) with the field names
// the widgets below already used.
class ExamItem {
  final CrmStudentExam exam;
  const ExamItem(this.exam);

  DateTime? get ngayThi => exam.examDate;
  String get gioBatDau => exam.startTime;
  int get thoiGian => exam.durationMinutes;
  // `room` is frequently null in the CRM's IMS mirror (documented data
  // quality gap, not a join bug) — shown as "—" rather than blank.
  String get phongten => exam.room?.trim().isNotEmpty == true
      ? exam.room!.trim()
      : '—';
  String get loaiThi => exam.examType;
  String get mhten => exam.subjectName;
  String get hkma => exam.semesterCode;
  String get hkten => semesterCodeLabel(exam.semesterCode);

  String get ngayThiFormatted => exam.examDateFormatted;
}

// ── Screen ───────────────────────────────────────────────
class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  // Bản toàn bộ lịch sử (không lọc học kỳ) — dùng để dựng danh sách học kỳ
  // trong dropdown và làm nội dung của lựa chọn "Tất cả".
  List<ExamItem> _allExams = [];
  // Những gì đang hiện trên màn — bằng _allExams khi _selectedHkma rỗng
  // ("Tất cả"), hoặc kết quả một lần gọi lọc riêng theo học kỳ đã chọn.
  List<ExamItem> _displayExams = [];
  List<({String hkma, String hkten})> _semesters = [];
  String _selectedHkma = ''; // '' = Tất cả các học kỳ
  bool _loading = true;
  bool _switchingSemester = false;
  String? _error;

  static const String allLabel = 'Tất cả các học kỳ';

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  // `GET /api/student/me/exams` KHÔNG kèm `semester` (hoặc `semester=all`)
  // trả TOÀN BỘ lịch sử thi, mới nhất trước — mặc định của màn hình này.
  // `?semester=<mã>` lọc đúng một học kỳ, chỉ gọi khi người dùng CHỌN một
  // học kỳ cụ thể ở dropdown (xem _onSemesterChanged). Đây là hợp đồng MỚI
  // của server (2026-09-25) — trước đó không truyền `semester` chỉ trả học
  // kỳ hiện tại, và exam_screen từng phải tự dựng lịch sử bằng cách gọi lặp
  // theo từng mã học kỳ lấy từ /me/sections; không còn cần nữa. Xem
  // docs/ims_to_crm_student_academic_map.md.
  Future<void> _fetchExams() async {
    setState(() { _loading = true; _error = null; });
    try {
      final view = await CrmStudentApi.exams();
      final exams = view.exams.map(ExamItem.new).toList()
        ..sort((a, b) {
          final da = a.ngayThi ?? DateTime(0);
          final db = b.ngayThi ?? DateTime(0);
          return db.compareTo(da);
        });

      // Lấy danh sách học kỳ duy nhất, giữ thứ tự mới → cũ
      final seen = <String>{};
      final semesters = exams
          .map((e) => (hkma: e.hkma, hkten: e.hkten))
          .where((s) => s.hkma.isNotEmpty && seen.add(s.hkma))
          .toList()
        ..sort((a, b) => b.hkma.compareTo(a.hkma));

      if (!mounted) return;
      setState(() {
        _allExams = exams;
        _displayExams = exams;
        _semesters = semesters;
        _selectedHkma = '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // Người dùng chọn một học kỳ cụ thể (hoặc quay về "Tất cả"). Chỉ "Tất cả"
  // dùng lại bản đã tải; một học kỳ cụ thể LUÔN gọi lại server với
  // `semester=` đúng như hợp đồng mới, thay vì lọc từ bản toàn bộ đang có
  // trong bộ nhớ — để danh sách hiện đúng những gì server coi là thuộc học
  // kỳ đó.
  Future<void> _onSemesterChanged(String hkma) async {
    setState(() => _selectedHkma = hkma);
    if (hkma.isEmpty) {
      setState(() => _displayExams = _allExams);
      return;
    }
    setState(() => _switchingSemester = true);
    try {
      final view = await CrmStudentApi.exams(semester: hkma);
      if (!mounted) return;
      setState(() {
        _displayExams = view.exams.map(ExamItem.new).toList()
          ..sort((a, b) {
            final da = a.ngayThi ?? DateTime(0);
            final db = b.ngayThi ?? DateTime(0);
            return db.compareTo(da);
          });
        _switchingSemester = false;
      });
    } catch (_) {
      // Giữ danh sách cũ trên màn hình; chỉ tắt vòng xoay tải.
      if (mounted) setState(() => _switchingSemester = false);
    }
  }

  List<ExamItem> get _filtered => _displayExams;


  @override
  Widget build(BuildContext context) {
    final exams = _filtered;

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
                      'Lịch thi',
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

                // Semester dropdown
                if (!_loading && _semesters.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedHkma,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        iconEnabledColor: const Color(0xFFE65100),
                        icon: const Icon(Icons.expand_more_rounded, size: 20),
                        isDense: true,
                        style: const TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        selectedItemBuilder: (_) => [
                          const Center(
                            child: Text(allLabel,
                                style: TextStyle(
                                  color: Color(0xFFE65100),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                )),
                          ),
                          ..._semesters.map((s) => Center(
                                child: Text(s.hkten,
                                    style: const TextStyle(
                                      color: Color(0xFFE65100),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    )),
                              )),
                        ],
                        items: [
                          const DropdownMenuItem(value: '', child: Text(allLabel)),
                          ..._semesters.map((s) => DropdownMenuItem(
                                value: s.hkma,
                                child: Text(s.hkten),
                              )),
                        ],
                        onChanged: (v) { if (v != null) _onSemesterChanged(v); },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: _loading || _switchingSemester
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE65100)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Color.fromARGB(255, 0, 0, 0)),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0))),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchExams,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFE65100)),
                              child: const Text('Thử lại',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : exams.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_busy,
                                    size: 64, color: Color.fromARGB(255, 0, 0, 0)),
                                SizedBox(height: 12),
                                Text('Không có lịch thi',
                                    style: TextStyle(color: Color.fromARGB(255, 0, 0, 0))),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFFE65100),
                            onRefresh: () => _selectedHkma.isEmpty
                                ? _fetchExams()
                                : _onSemesterChanged(_selectedHkma),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              itemCount: exams.length,
                              itemBuilder: (context, i) =>
                                  _ExamCard(exam: exams[i]),
                            ),
                          ),
          ),
        ],
      )),
    );
  }
}

// ── Exam Card ─────────────────────────────────────────────
class _ExamCard extends StatelessWidget {
  final ExamItem exam;
  const _ExamCard({required this.exam});

  Color get _loaiColor => exam.loaiThi.contains('Giữa')
      ? const Color(0xFF2196F3)
      : const Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Thanh màu trái
          Container(
            width: 5,
            height: 100,
            decoration: BoxDecoration(
              color: _loaiColor,
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
                  // Tên môn + badge loại thi
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          exam.mhten,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: _loaiColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          exam.loaiThi,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _loaiColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Ngày + giờ
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 13, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Text(exam.ngayThiFormatted,
                          style: const TextStyle(
                              fontSize: 12, color: Color.fromARGB(255, 0, 0, 0))),
                      const SizedBox(width: 14),
                      const Icon(Icons.access_time,
                          size: 13, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Text(exam.gioBatDau,
                          style: const TextStyle(
                              fontSize: 12, color: Color.fromARGB(255, 0, 0, 0))),
                      const SizedBox(width: 14),
                      const Icon(Icons.timer_outlined,
                          size: 13, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Text('${exam.thoiGian} phút',
                          style: const TextStyle(
                              fontSize: 12, color: Color.fromARGB(255, 0, 0, 0))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Phòng thi
                  Row(
                    children: [
                      const Icon(Icons.room,
                          size: 13, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Text(exam.phongten,
                          style: const TextStyle(
                              fontSize: 12, color: Color.fromARGB(255, 0, 0, 0))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
