import 'package:flutter/material.dart';
import '../services/ems_api_service.dart';
import '../theme/vd_theme.dart';
import '../data/api/attendance_api.dart';
import '../data/api/student_cases_api.dart';
/// Một mặt làm việc duy nhất cho giảng viên: buổi dạy hôm nay từ EMS và các
/// ca sinh viên đang chờ chính người này phản hồi từ Student Cases.
///
/// Hai phần tải độc lập. Lịch điểm danh hỏng không được che hàng đợi sinh viên,
/// và hàng đợi hỏng cũng không được làm biến mất lịch dạy.
class TeacherMyDayScreen extends StatefulWidget {
  const TeacherMyDayScreen({super.key});

  @override
  State<TeacherMyDayScreen> createState() => _TeacherMyDayScreenState();
}

class _TeacherMyDayScreenState extends State<TeacherMyDayScreen> {
  List<EmsSession>? _sessions;
  List<TeacherStudentCase>? _cases;
  String? _sessionsError;
  String? _casesError;
  final Set<String> _answering = {};

  bool get _loading => _sessions == null && _cases == null;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _sessionsError = null;
        _casesError = null;
      });
    }
    await Future.wait([_loadSessions(), _loadCases()]);
  }

  Future<void> _loadSessions() async {
    try {
      final rows = await AttendanceApi.mySessions(date: _today());
      if (!mounted) return;
      setState(() {
        _sessions = rows;
        _sessionsError = null;
      });
    } on EmsException catch (e) {
      if (!mounted) return;
      setState(() {
        _sessions = const [];
        _sessionsError =
            'Không có kết nối. Kiểm tra mạng và thử lại. ${e.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessions = const [];
        _sessionsError = 'Không có kết nối. Thử tải lại lịch dạy.';
      });
    }
  }

  Future<void> _loadCases() async {
    try {
      final rows = await StudentCasesApi.myOpenStudentCases();
      if (!mounted) return;
      setState(() {
        _cases = rows;
        _casesError = null;
      });
    } on EmsException catch (e) {
      if (!mounted) return;
      setState(() {
        _cases = const [];
        _casesError =
            'Không có kết nối. Kiểm tra mạng và thử lại. ${e.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cases = const [];
        _casesError = 'Không có kết nối. Thử tải lại sinh viên cần phản hồi.';
      });
    }
  }

  Future<void> _answer(TeacherStudentCase item) async {
    final answer = await showDialog<String>(
      context: context,
      builder: (context) => const _AnswerDialog(),
    );
    if (answer == null || answer.trim().isEmpty || !mounted) return;

    setState(() => _answering.add(item.id));
    try {
      final result = await StudentCasesApi.answerStudentCase(item.id, answer);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.requiresApproval
                ? 'Đã gửi phản hồi — đang chờ Ban Giám hiệu duyệt.'
                : 'Đã ghi nhận phản hồi chính thức.',
          ),
          backgroundColor: result.requiresApproval
              ? const Color(0xFFF57C00)
              : const Color(0xFF2E7D32),
        ),
      );
      await _loadCases();
    } on EmsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red[700]),
      );
    } finally {
      if (mounted) setState(() => _answering.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions ?? const <EmsSession>[];
    final cases = _cases ?? const <TeacherStudentCase>[];
    final unmarked = sessions.where((s) => !s.isMarked).length;
    final overdue = cases.where((c) => c.isOverdue).length;

    return Scaffold(
      backgroundColor: VdColors.cream,
      appBar: AppBar(
        title: const Text('Ngày làm việc của tôi'),
        backgroundColor: VdColors.headerTop,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _DaySummary(
              loading: _loading,
              sessions: sessions.length,
              unmarked: unmarked,
              cases: cases.length,
              overdue: overdue,
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              icon: Icons.school_outlined,
              title: 'Buổi dạy hôm nay',
              badge: _sessions == null ? null : '${sessions.length}',
            ),
            const SizedBox(height: 10),
            if (_sessions == null)
              const _LoadingBlock()
            else ...[
              if (_sessionsError != null)
                _InlineError(message: _sessionsError!, onRetry: _loadSessions),
              if (sessions.isEmpty && _sessionsError == null)
                const _EmptyBlock(
                  icon: Icons.event_available,
                  text: 'Hôm nay không có buổi dạy trong lịch EMS.',
                )
              else
                ...sessions.map(_sessionCard),
            ],
            const SizedBox(height: 22),
            _SectionTitle(
              icon: Icons.support_agent,
              title: 'Sinh viên cần tôi phản hồi',
              badge: _cases == null ? null : '${cases.length}',
            ),
            const SizedBox(height: 4),
            const Text(
              'Ca được giao hoặc định tuyến tới bạn. Câu trả lời được lưu vào '
              'nhật ký xử lý của nhà trường.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            if (_cases == null)
              const _LoadingBlock()
            else ...[
              if (_casesError != null)
                _InlineError(message: _casesError!, onRetry: _loadCases),
              if (cases.isEmpty && _casesError == null)
                const _EmptyBlock(
                  icon: Icons.task_alt,
                  text: 'Không có sinh viên nào đang chờ bạn phản hồi.',
                )
              else
                ...cases.map(_caseCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sessionCard(EmsSession session) {
    final complete =
        session.rosterSize > 0 && session.markedCount >= session.rosterSize;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pushNamed(context, '/ems_attendance_gv'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (complete ? Colors.green : const Color(0xFFE65100))
                      .withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  complete ? Icons.check_circle_outline : Icons.how_to_reg,
                  color: complete ? Colors.green[700] : const Color(0xFFE65100),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.subjectName?.trim().isNotEmpty == true
                          ? session.subjectName!
                          : session.sectionCode,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.timeLabel}'
                      '${session.room?.trim().isNotEmpty == true ? ' · ${session.room}' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.rosterSize == 0
                          ? 'Chưa có danh sách lớp'
                          : '${session.markedCount}/${session.rosterSize} đã điểm danh',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: complete
                            ? Colors.green[700]
                            : Colors.orange[800],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _caseCard(TeacherStudentCase item) {
    final busy = _answering.contains(item.id);
    final urgent = item.priority == 'urgent' || item.priority == 'high';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: item.isOverdue ? Colors.red.shade200 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (urgent || item.isOverdue)
                  _StatusChip(
                    label: item.isOverdue ? 'QUÁ HẠN' : 'ƯU TIÊN',
                    color: Colors.red[700]!,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${item.studentName.isEmpty ? 'Sinh viên' : item.studentName} · ${item.studentMssv}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF37474F),
              ),
            ),
            if (item.description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                item.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Colors.black87,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusChip(
                  label: _relationLabel(item.relation),
                  color: Colors.blueGrey,
                ),
                _StatusChip(
                  label: _statusLabel(item.status),
                  color: const Color(0xFFE65100),
                ),
                if (item.dueAt != null)
                  _StatusChip(
                    label: 'Hạn ${_formatDate(item.dueAt!)}',
                    color: Colors.grey[700]!,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : () => _answer(item),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.reply, size: 18),
                label: Text(busy ? 'Đang gửi…' : 'Phản hồi ca sinh viên'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}';

  static String _relationLabel(String relation) => switch (relation) {
    'primary' => 'Phụ trách chính',
    'watcher' => 'Cùng theo dõi',
    'department_queue' => 'Hàng đợi bộ môn',
    _ => 'Được giao',
  };

  static String _statusLabel(String status) => switch (status) {
    'open' => 'Mới',
    'in_progress' => 'Đang xử lý',
    'waiting_for_school' => 'Chờ nhà trường',
    'pending_approval' => 'Chờ duyệt',
    _ => status,
  };
}

class _DaySummary extends StatelessWidget {
  final bool loading;
  final int sessions;
  final int unmarked;
  final int cases;
  final int overdue;

  const _DaySummary({
    required this.loading,
    required this.sessions,
    required this.unmarked,
    required this.cases,
    required this.overdue,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingBlock(height: 112);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ưu tiên hôm nay',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryNumber(value: '$sessions', label: 'buổi dạy'),
              _SummaryNumber(value: '$unmarked', label: 'chưa điểm danh'),
              _SummaryNumber(value: '$cases', label: 'ca cần phản hồi'),
              _SummaryNumber(value: '$overdue', label: 'quá hạn'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryNumber extends StatelessWidget {
  final String value;
  final String label;
  const _SummaryNumber({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  const _SectionTitle({required this.icon, required this.title, this.badge});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: const Color(0xFFE65100)),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      if (badge != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE0B2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge!,
            style: const TextStyle(
              color: Color(0xFFE65100),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
    ],
  );
}

class _InlineError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red[50],
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(Icons.cloud_off, color: Colors.red[700]),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}

class _EmptyBlock extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyBlock({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.green[700]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.black54)),
        ),
      ],
    ),
  );
}

class _LoadingBlock extends StatelessWidget {
  final double height;
  const _LoadingBlock({this.height = 84});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Color(0xFFE65100),
        ),
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _AnswerDialog extends StatefulWidget {
  const _AnswerDialog();

  @override
  State<_AnswerDialog> createState() => _AnswerDialogState();
}

class _AnswerDialogState extends State<_AnswerDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Phản hồi ca sinh viên'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      minLines: 4,
      maxLines: 8,
      maxLength: 5000,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        hintText: 'Đã liên hệ ai, đã làm gì, kết quả và bước tiếp theo…',
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Huỷ'),
      ),
      FilledButton(
        onPressed: _controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Gửi phản hồi'),
      ),
    ],
  );
}
