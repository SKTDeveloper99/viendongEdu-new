import 'package:flutter/material.dart';

import '../../../data/teaching_report_repository.dart';
import '../../../models/teaching_report_models.dart';
import '../../../theme/vd_tokens.dart';
import '../teaching_report_flow.dart';

/// "Buổi chưa báo cáo giảng dạy" in Ngày làm việc của tôi: my sessions up to
/// today with no T-28 report (tap to report), and reports kept on this phone
/// that have not reached the server yet ("CHƯA GỬI").
class PendingTeachingReports extends StatefulWidget {
  /// Bump to reload (pull-to-refresh of the parent screen).
  final int reloadSignal;
  final TeachingReportRepository repository;
  const PendingTeachingReports({
    super.key,
    this.reloadSignal = 0,
    this.repository = const TeachingReportRepository(),
  });

  @override
  State<PendingTeachingReports> createState() => _PendingTeachingReportsState();
}

class _PendingTeachingReportsState extends State<PendingTeachingReports> {
  List<TeachingReportSession>? _pending;
  List<QueuedTeachingReport> _queued = const [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PendingTeachingReports old) {
    super.didUpdateWidget(old);
    if (old.reloadSignal != widget.reloadSignal) _load();
  }

  Future<void> _load() async {
    final repo = widget.repository;
    await repo.drain();
    final queued = await repo.queued();
    List<TeachingReportSession>? pending;
    try {
      pending = await repo.pending();
    } catch (_) {
      pending = null;
    }
    if (!mounted) return;
    setState(() {
      _queued = queued;
      _pending = pending ?? _pending ?? const [];
      _failed = pending == null;
    });
  }

  Future<void> _report(TeachingReportSession s) async {
    await askAndReport(
      context,
      report: (choice) => QueuedTeachingReport(
        sectionCode: s.sectionCode,
        meetingDate: s.meetingDate,
        startTime: s.startTime,
        subjectName: s.subjectName,
        choice: choice,
        createdAt: DateTime.now(),
      ),
      title: '${s.subjectName} · ${s.sectionCode}',
      when:
          '${reportDate(s.meetingDate)} · ${s.startTime}'
          '${s.endTime == null ? '' : ' – ${s.endTime}'}',
      scheduledPeriods: s.scheduledPeriods,
      known: _pending,
      repository: widget.repository,
    );
    await _load();
  }

  Future<void> _discard(QueuedTeachingReport q) async {
    await widget.repository.discard(q.key);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final queuedKeys = _queued.map((q) => q.key).toSet();
    final open = (_pending ?? const <TeachingReportSession>[])
        .where((s) => !queuedKeys.contains(s.key))
        .toList();
    final count = open.length + _queued.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assignment_outlined, size: 20, color: vd.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Buổi chưa báo cáo giảng dạy',
                style: TextStyle(fontWeight: FontWeight.w700, color: vd.ink),
              ),
            ),
            if (_pending != null)
              Text('$count', style: TextStyle(color: vd.inkMuted)),
          ],
        ),
        const SizedBox(height: 8),
        if (_pending == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (_failed)
            TextButton(
              onPressed: _load,
              child: const Text('Chưa tải được danh sách từ máy chủ. Thử lại'),
            ),
          if (count == 0 && !_failed)
            Text(
              'Không còn buổi nào chưa báo cáo.',
              style: TextStyle(color: vd.inkMuted),
            ),
          for (final q in _queued)
            Card(
              child: ListTile(
                title: Text(q.subjectName),
                subtitle: Text(
                  '${reportDate(q.meetingDate)} · ${q.startTime}\n'
                  'CHƯA GỬI — ${q.choice.summary}'
                  '${q.problem == null ? '' : '\n${q.problem}'}',
                  style: TextStyle(color: vd.warning),
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Bỏ báo cáo chưa gửi',
                  onPressed: () => _discard(q),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
          for (final s in open)
            Card(
              child: ListTile(
                title: Text(s.subjectName),
                subtitle: Text(
                  '${s.sectionCode} · ${reportDate(s.meetingDate)} · ${s.startTime}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _report(s),
              ),
            ),
        ],
      ],
    );
  }
}
