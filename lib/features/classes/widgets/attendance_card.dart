import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../theme/vd_tokens.dart';

/// Donut chart and legend of a class's sessions.
///
/// Presence % counts only sessions with an outcome (present, absent, báo
/// nghỉ). Sessions without a mark are split by date (Sắp tới, Chờ điểm danh,
/// Chưa có dữ liệu), shown in neutral greys and never counted as absent.
class AttendanceCard extends StatelessWidget {
  final int total;
  final int present;
  final int absent;
  final int excused;
  final int upcoming;
  final int awaiting;
  final int noData;

  const AttendanceCard({
    super.key,
    required this.total,
    required this.present,
    required this.absent,
    this.excused = 0,
    this.upcoming = 0,
    this.awaiting = 0,
    this.noData = 0,
  });

  int get _decided => present + absent + excused;

  @override
  Widget build(BuildContext context) {
    final pct = _decided > 0 ? (present / _decided * 100).round() : null;

    return Container(
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: context.vd.shadow, blurRadius: 6, offset: Offset(0, 3)),
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
              _donut(context, pct),
              const SizedBox(width: 20),
              Expanded(child: _legend(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _donut(BuildContext context, int? pct) {
    return SizedBox(
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
                if (present > 0) _slice(present, context.vd.success),
                if (absent > 0) _slice(absent, context.vd.danger),
                if (excused > 0) _slice(excused, context.vd.info),
                if (awaiting + upcoming > 0)
                  _slice(awaiting + upcoming, context.vd.inkFaint),
                if (noData > 0) _slice(noData, context.vd.hairline),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(pct == null ? '—' : '$pct%',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.vd.ink)),
              Text('có mặt',
                  style: TextStyle(fontSize: 10, color: context.vd.inkMuted)),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _slice(int value, Color color) => PieChartSectionData(
        value: value.toDouble(),
        color: color,
        radius: 28,
        showTitle: false,
      );

  Widget _legend(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegendRow(context.vd.success, 'Có mặt', present, _decided),
        const SizedBox(height: 10),
        _LegendRow(context.vd.danger, 'Vắng', absent, _decided),
        if (excused > 0) ...[
          const SizedBox(height: 10),
          _LegendRow(context.vd.info, 'Báo nghỉ', excused, _decided),
        ],
        for (final (label, n, color) in [
          ('Chờ điểm danh', awaiting, context.vd.inkFaint),
          ('Sắp tới', upcoming, context.vd.inkFaint),
          ('Chưa có dữ liệu', noData, context.vd.hairline),
        ])
          if (n > 0) ...[
            const SizedBox(height: 10),
            _LegendRow(color, label, n, null),
          ],
        const Divider(height: 20),
        Row(
          children: [
            Icon(Icons.layers_outlined,
                size: 15, color: context.vd.primary),
            const SizedBox(width: 6),
            Text('Tổng: $total buổi',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  /// Denominator for the percentage; null = count only (no outcome yet).
  final int? total;
  const _LegendRow(this.color, this.label, this.count, this.total);

  @override
  Widget build(BuildContext context) {
    final t = total;
    final suffix = t == null || t == 0 ? '' : '  (${(count / t * 100).round()}%)';
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 12, color: context.vd.inkMuted)),
        ),
        Text('$count$suffix',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: total == null ? context.vd.inkMuted : color)),
      ],
    );
  }
}
