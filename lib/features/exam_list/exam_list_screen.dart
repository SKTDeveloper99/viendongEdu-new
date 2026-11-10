import 'package:flutter/material.dart';

import '../../data/exam_list_repository.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import 'exam_roster_screen.dart';

String ddMMyyyy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// "Danh sách thi" (T3): my classes with an exam from today on. Tap a class
/// for its students' exam status.
class ExamListScreen extends StatefulWidget {
  final ExamListRepository repository;
  final DateTime Function()? now;
  const ExamListScreen({
    super.key,
    this.repository = const ExamListRepository(),
    this.now,
  });

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  List<UpcomingExamClass>? _items;
  String? _error;

  DateTime get _today => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await widget.repository.upcoming(_today);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      if (mounted) {
        setState(() {
          _items ??= const [];
          _error = crmErrorMessage(e);
        });
      }
    }
  }

  String _when(DateTime day) {
    final d = DateTime(_today.year, _today.month, _today.day);
    final diff = day.difference(d).inDays;
    final label = diff == 0
        ? 'Hôm nay'
        : diff == 1
        ? 'Ngày mai'
        : 'Còn $diff ngày';
    return '${ddMMyyyy(day)} · $label';
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final items = _items;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(
        title: const Text('Danh sách thi'),
        backgroundColor: vd.headerTop,
        foregroundColor: vd.onHeader,
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Lớp của bạn có lịch thi từ hôm nay. Chạm vào lớp để xem '
                    'ai được thi. Chỉ hiện trạng thái, không hiện số tiền.',
                    style: TextStyle(fontSize: 13, color: vd.inkMuted),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: vd.danger)),
                    TextButton(onPressed: _load, child: const Text('Thử lại')),
                  ],
                  if (items.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Text(
                        'Chưa có lớp nào có lịch thi sắp tới.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: vd.inkMuted),
                      ),
                    ),
                  for (final e in items)
                    Card(
                      child: ListTile(
                        title: Text(
                          e.klass.subjectName?.isNotEmpty == true
                              ? e.klass.subjectName!
                              : e.klass.sectionCode,
                        ),
                        subtitle: Text(
                          '${e.klass.sectionCode}\n${_when(e.examDay)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExamRosterScreen(
                              exam: e,
                              repository: widget.repository,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
