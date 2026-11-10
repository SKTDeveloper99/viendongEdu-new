import 'package:flutter/material.dart';

import '../../data/exam_list_repository.dart';
import '../../models/exam_status_models.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import 'exam_list_screen.dart' show ddMMyyyy;
import 'widgets/exam_status_pill.dart';

/// One class on exam morning: every student with one status pill.
class ExamRosterScreen extends StatefulWidget {
  final UpcomingExamClass exam;
  final ExamListRepository repository;
  const ExamRosterScreen({
    super.key,
    required this.exam,
    this.repository = const ExamListRepository(),
  });

  @override
  State<ExamRosterScreen> createState() => _ExamRosterScreenState();
}

class _ExamRosterScreenState extends State<ExamRosterScreen> {
  ExamRosterStatus? _roster;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await widget.repository.roster(widget.exam.klass.sectionId);
      if (mounted) setState(() => _roster = r);
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (mounted) setState(() => _error = crmErrorMessage(e));
    }
  }

  String _stamp(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} '
      '${ddMMyyyy(t)}';

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final r = _roster;
    final k = widget.exam.klass;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(
        title: Text(
          k.subjectName?.isNotEmpty == true ? k.subjectName! : k.sectionCode,
        ),
        backgroundColor: vd.headerTop,
        foregroundColor: vd.onHeader,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${k.sectionCode} · Ngày thi ${ddMMyyyy(widget.exam.examDay)}',
              style: TextStyle(fontWeight: FontWeight.w600, color: vd.ink),
            ),
            const SizedBox(height: 8),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: vd.danger)),
              TextButton(onPressed: _load, child: const Text('Thử lại')),
            ],
            if (r == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (r != null) ...[
              if (r.savedAt != null)
                Text(
                  'Chưa cập nhật được — bản lưu lúc ${_stamp(r.savedAt!)}.',
                  style: TextStyle(fontSize: 12, color: vd.warning),
                ),
              if (r.asOf != null)
                Text(
                  'Dữ liệu học phí cập nhật lúc ${_stamp(r.asOf!)}'
                  '${r.stale ? ' (đã cũ hơn một ngày)' : ''}.',
                  style: TextStyle(fontSize: 12, color: vd.inkMuted),
                ),
              const SizedBox(height: 8),
              Text(
                '${r.count(ExamMoneyStatus.allowed)} được thi · '
                '${r.count(ExamMoneyStatus.owes)} còn nợ · '
                '${r.count(ExamMoneyStatus.noData)} chưa có dữ liệu',
                style: TextStyle(fontWeight: FontWeight.w700, color: vd.ink),
              ),
              const Divider(height: 24),
              if (r.students.isEmpty)
                Text(
                  'Lớp chưa có sinh viên.',
                  style: TextStyle(color: vd.inkMuted),
                ),
              for (var i = 0; i < r.students.length; i++)
                ExamStatusRow(student: r.students[i], index: i + 1),
            ],
          ],
        ),
      ),
    );
  }
}
