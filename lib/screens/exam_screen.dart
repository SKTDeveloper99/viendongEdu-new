import '../core/network/ems_exception.dart';
import '../components/skeleton.dart';
import 'stale_note.dart';
import '../components/student_notices.dart';
import '../models/student_notice.dart';
import 'package:flutter/material.dart';
import '../components/student_exam_card.dart';
import '../services/crm_student_api.dart';
import '../services/crm_session_guard.dart';
import '../theme/vd_tokens.dart';

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
  int _request = 0;
  DateTime? _staleAt;
  DateTime? _allStaleAt;
  List<StudentNotice> _notices = const [];

  static const String allLabel = 'Tất cả các học kỳ';

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  // Load every semester; explicit selections make their own filtered read.
  Future<void> _fetchExams() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await CrmStudentApi.examsCached();
      final view = r.data;
      final exams = view.exams.map(ExamItem.new).toList()
        ..sort((a, b) {
          final da = a.ngayThi ?? DateTime(0);
          final db = b.ngayThi ?? DateTime(0);
          return db.compareTo(da);
        });

      // Lấy danh sách học kỳ duy nhất, giữ thứ tự mới → cũ
      final seen = <String>{};
      final semesters =
          exams
              .map((e) => (hkma: e.hkma, hkten: e.hkten))
              .where((s) => s.hkma.isNotEmpty && seen.add(s.hkma))
              .toList()
            ..sort((a, b) => b.hkma.compareTo(a.hkma));

      if (!mounted || request != _request) return;
      setState(() {
        _staleAt = r.fresh ? null : r.savedAt;
        _allStaleAt = _staleAt;
        _notices = view.notices;
        _allExams = exams;
        _displayExams = exams;
        _semesters = semesters;
        _selectedHkma = '';
        _switchingSemester = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      if (await handleCrmAuthError(context, e)) return;
      setState(() {
        _loading = false;
        _switchingSemester = false;
        _error = crmErrorMessage(e);
      });
    }
  }

  // Reload the selected semester; never relabel the previous semester's data.
  Future<void> _onSemesterChanged(String hkma) async {
    final request = ++_request;
    setState(() {
      _selectedHkma = hkma;
      _error = null;
      _switchingSemester = false;
    });
    if (hkma.isEmpty) {
      setState(() {
        _displayExams = _allExams;
        _staleAt = _allStaleAt;
      });
      return;
    }
    setState(() {
      _switchingSemester = true;
      _error = null;
    });
    try {
      final r = await CrmStudentApi.examsCached(semester: hkma);
      final view = r.data;
      if (!mounted || request != _request) return;
      setState(() {
        _staleAt = r.fresh ? null : r.savedAt;
        _allStaleAt ??= _staleAt;
        _displayExams = view.exams.map(ExamItem.new).toList()
          ..sort((a, b) {
            final da = a.ngayThi ?? DateTime(0);
            final db = b.ngayThi ?? DateTime(0);
            return db.compareTo(da);
          });
        final seenIds = <String>{};
        _allExams =
            [..._allExams.where((e) => e.hkma != hkma), ..._displayExams]
                .where(
                  (e) => e.exam.examId.isEmpty || seenIds.add(e.exam.examId),
                )
                .toList();
        _switchingSemester = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      if (await handleCrmAuthError(context, e)) return;
      if (!mounted || request != _request) return;
      setState(() {
        _switchingSemester = false;
        _displayExams = [];
        _error = crmErrorMessage(e);
      });
    }
  }

  List<ExamItem> get _filtered => _displayExams;

  @override
  Widget build(BuildContext context) {
    final exams = _filtered;

    return Scaffold(
      backgroundColor: context.vd.bg,
      body: SafeArea(
        top: false,
        child: Column(
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
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.arrow_back_ios,
                          color: context.vd.onPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lịch thi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.vd.onPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Text(
                  //   'MSSV: ${AppSession.instance.hocVien?.mshv ?? ''}',
                  //   style: const TextStyle(color: context.vd.onPrimary.withValues(alpha: 0.7), fontSize: 13),
                  // ),
                  const SizedBox(height: 16),

                  // Semester dropdown
                  if (!_loading && _semesters.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.only(
                        left: 14,
                        right: 6,
                        top: 6,
                        bottom: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.vd.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: context.vd.shadow,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedHkma,
                          dropdownColor: context.vd.surface,
                          borderRadius: BorderRadius.circular(14),
                          iconEnabledColor: context.vd.primary,
                          icon: const Icon(Icons.expand_more_rounded, size: 20),
                          isDense: true,
                          style: TextStyle(
                            color: context.vd.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          selectedItemBuilder: (_) => [
                            Center(
                              child: Text(
                                allLabel,
                                style: TextStyle(
                                  color: context.vd.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ..._semesters.map(
                              (s) => Center(
                                child: Text(
                                  s.hkten,
                                  style: TextStyle(
                                    color: context.vd.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text(allLabel),
                            ),
                            ..._semesters.map(
                              (s) => DropdownMenuItem(
                                value: s.hkma,
                                child: Text(s.hkten),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) _onSemesterChanged(v);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (_staleAt != null) StaleNote(_staleAt!),
            if (!_loading && !_switchingSemester)
              StudentNoticeList(
                notices: _notices,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              ),
            // ── Content ──
            Expanded(
              child: _loading || _switchingSemester
                  ? skeletonList(accentColor: context.vd.primary)
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchExams,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.vd.primary,
                            ),
                            child: Text(
                              'Thử lại',
                              style: TextStyle(color: context.vd.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    )
                  : exams.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _fetchExams,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_busy,
                                  size: 64,
                                  color: Color.fromARGB(255, 0, 0, 0),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Không có lịch thi',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: context.vd.primary,
                      onRefresh: () => _selectedHkma.isEmpty
                          ? _fetchExams()
                          : _onSemesterChanged(_selectedHkma),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: exams.length,
                        itemBuilder: (context, i) =>
                            StudentExamCard(exam: exams[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Exam Card ─────────────────────────────────────────────
