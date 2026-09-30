import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';
import 'gv_class_chip.dart' show gvBuoiFor;

const _dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// Mon–Sun strip above "Lịch dạy": today outlined, the selected day filled,
/// 0–3 dots per day (one per teaching session, coloured by Sáng/Chiều/Tối).
/// Chevrons or a horizontal swipe change the week.
class WeekStrip extends StatefulWidget {
  final DateTime today;
  final DateTime selected;

  /// Start times ("HH:MM") of the sessions on a day; at most 3 are drawn.
  final List<String> Function(DateTime day) dotStartsFor;
  final ValueChanged<DateTime> onSelect;
  const WeekStrip({
    super.key,
    required this.today,
    required this.selected,
    required this.dotStartsFor,
    required this.onSelect,
  });

  @override
  State<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<WeekStrip> {
  late DateTime _monday = _mondayOf(widget.selected);

  static DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  void _shift(int weeks) => setState(
    () => _monday = DateTime(
      _monday.year,
      _monday.month,
      _monday.day + 7 * weeks,
    ),
  );

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -200) _shift(1);
        if (v > 200) _shift(-1);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Tuần trước',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.chevron_left, color: t.inkMuted),
              onPressed: () => _shift(-1),
            ),
            for (var i = 0; i < 7; i++)
              Expanded(
                child: _dayCell(
                  context,
                  DateTime(_monday.year, _monday.month, _monday.day + i),
                  i,
                ),
              ),
            IconButton(
              tooltip: 'Tuần sau',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.chevron_right, color: t.inkMuted),
              onPressed: () => _shift(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(BuildContext context, DateTime day, int i) {
    final t = context.vd;
    final isToday = _same(day, widget.today);
    final isSel = _same(day, widget.selected);
    final starts = widget.dotStartsFor(day).take(3).toList();
    return InkWell(
      key: ValueKey('week-day-${day.year}-${day.month}-${day.day}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => widget.onSelect(day),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _dayLabels[i],
              style: TextStyle(fontSize: 11, color: t.inkMuted),
            ),
            const SizedBox(height: 4),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSel ? t.primary : null,
                border: isToday
                    ? Border.all(color: t.primary, width: 1.5)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSel || isToday
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: isSel ? t.onPrimary : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Fixed height so 0 dots and 3 dots lay out the same.
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (n, s) in starts.indexed)
                    Container(
                      key: ValueKey('week-dot-$n'),
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gvBuoiFor(s, null, t).color,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
