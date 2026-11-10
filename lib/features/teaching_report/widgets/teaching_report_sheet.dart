import 'package:flutter/material.dart';

import '../../../models/teaching_report_models.dart';
import '../../../theme/vd_tokens.dart';

/// "Báo cáo giảng dạy buổi này" (LAW T-28). The teacher always taps: one tap
/// for the full timetable periods (when known), a stepper for fewer, or
/// "Buổi học nghỉ". Null = "Để sau" (the session stays in Ngày làm việc).
Future<TeachingReportChoice?> showTeachingReportSheet(
  BuildContext context, {
  required String title,
  required String when,
  int? scheduledPeriods,
}) => showModalBottomSheet<TeachingReportChoice>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => TeachingReportSheet(
    title: title,
    when: when,
    scheduledPeriods: scheduledPeriods,
  ),
);

class TeachingReportSheet extends StatefulWidget {
  final String title;
  final String when;
  final int? scheduledPeriods;
  const TeachingReportSheet({
    super.key,
    required this.title,
    required this.when,
    this.scheduledPeriods,
  });

  @override
  State<TeachingReportSheet> createState() => _TeachingReportSheetState();
}

class _TeachingReportSheetState extends State<TeachingReportSheet> {
  final _note = TextEditingController();
  // Unknown timetable: the teacher sets the number (starts empty). Known:
  // the stepper starts one below it.
  late int _periods = _n == null || _max < 1 ? 0 : _max;

  int? get _n => widget.scheduledPeriods;

  /// Fewer than the timetable when it is known; otherwise 1–15.
  int get _max => _n == null ? 15 : _n! - 1;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _done(TeachingOutcome outcome, int periods) {
    final note = _note.text.trim();
    Navigator.pop(
      context,
      TeachingReportChoice(
        outcome: outcome,
        periods: periods,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final n = _n;
    final showStepper = n == null || n > 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Báo cáo giảng dạy buổi này',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: vd.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(widget.title, style: TextStyle(color: vd.ink)),
            Text(widget.when, style: TextStyle(color: vd.inkMuted)),
            const SizedBox(height: 4),
            Text(
              n == null
                  ? 'Chọn số tiết thực dạy.'
                  : 'Theo thời khóa biểu: $n tiết.',
              style: TextStyle(fontSize: 13, color: vd.inkMuted),
            ),
            const SizedBox(height: 16),
            if (n != null) ...[
              FilledButton(
                onPressed: () => _done(TeachingOutcome.held, n),
                child: Text('Đã dạy đủ $n tiết'),
              ),
              const SizedBox(height: 12),
            ],
            if (showStepper) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      n == null ? 'Đã dạy' : 'Dạy ít hơn',
                      style: TextStyle(color: vd.ink),
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Bớt một tiết',
                    onPressed: _periods > 1
                        ? () => setState(() => _periods--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      _periods == 0 ? '— tiết' : '$_periods tiết',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: vd.ink,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Thêm một tiết',
                    onPressed: _periods < _max
                        ? () => setState(() => _periods++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _periods >= 1
                    ? () => _done(TeachingOutcome.held, _periods)
                    : null,
                child: Text(
                  _periods >= 1 ? 'Gửi: đã dạy $_periods tiết' : 'Chọn số tiết',
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: () => _done(TeachingOutcome.cancelled, 0),
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Buổi học nghỉ'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (không bắt buộc)',
                border: OutlineInputBorder(),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Để sau'),
            ),
          ],
        ),
      ),
    );
  }
}
