import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Donut chart and legend of present / absent / not-yet-marked sessions.
class AttendanceCard extends StatelessWidget {
  final int total;
  final int present;
  final int absent;
  final int pending;

  const AttendanceCard({
    super.key,
    required this.total,
    required this.present,
    required this.absent,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (present / total * 100).round() : 0;

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
              _donut(pct),
              const SizedBox(width: 20),
              Expanded(child: _legend()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _donut(int pct) {
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
                if (present > 0) _slice(present, const Color(0xFF4CAF50)),
                if (absent > 0) _slice(absent, const Color(0xFFF44336)),
                if (pending > 0) _slice(pending, const Color(0xFFBDBDBD)),
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
    );
  }

  PieChartSectionData _slice(int value, Color color) => PieChartSectionData(
        value: value.toDouble(),
        color: color,
        radius: 28,
        showTitle: false,
      );

  Widget _legend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegendRow(const Color(0xFF4CAF50), 'Có mặt', present, total),
        const SizedBox(height: 10),
        _LegendRow(const Color(0xFFF44336), 'Vắng mặt', absent, total),
        const SizedBox(height: 10),
        _LegendRow(const Color(0xFFBDBDBD), 'Chưa điểm danh', pending, total),
        const Divider(height: 20),
        Row(
          children: [
            const Icon(Icons.layers_outlined,
                size: 15, color: Color(0xFFE65100)),
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
  final int total;
  const _LegendRow(this.color, this.label, this.count, this.total);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
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
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        Text('$count  ($pct%)',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
