import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../grade_item.dart';
import '../../../theme/vd_tokens.dart';

// Grade distribution with donut chart
class GradeDistribution extends StatelessWidget {
  final List<GradeItem> grades;
  const GradeDistribution({super.key, required this.grades});

  static Map<String, Color> _colorsOf(VdTokens t) => {
    'A': t.success,
    'B+': t.info,
    'B': t.info,
    'C+': t.accent,
    'C': t.accent,
    'D+': t.inkMuted,
    'D': t.inkMuted,
    'F': t.danger,
  };

  @override
  Widget build(BuildContext context) {
    if (grades.isEmpty) return const SizedBox.shrink();

    // Dùng grade.gradeLetter (rỗng khi không băng được) chứ không phải
    // GradeItem.diemchu (đã đổi rỗng thành "—" để hiển thị) — biểu đồ này chỉ
    // đếm điểm thật, không đếm "chưa có điểm/không băng được" như một loại.
    final Map<String, int> dist = {};
    for (final g in grades) {
      final letter = g.grade.gradeLetter;
      if (letter.isNotEmpty) {
        dist[letter] = (dist[letter] ?? 0) + 1;
      }
    }
    if (dist.isEmpty) return const SizedBox.shrink();

    final order = ['A', 'B+', 'B', 'C+', 'C', 'D+', 'D', 'F'];
    final entries = order
        .where((k) => dist.containsKey(k))
        .map((k) => MapEntry(k, dist[k]!))
        .toList();
    final total = entries.fold(0, (s, e) => s + e.value);

    final sections = entries.map((e) {
      return PieChartSectionData(
        value: e.value.toDouble(),
        color: _colorsOf(context.vd)[e.key] ?? context.vd.inkMuted,
        radius: 30,
        showTitle: false,
      );
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: context.vd.shadow, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Phân bổ điểm chữ',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              // Donut chart
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 34,
                        sectionsSpace: 2,
                        startDegreeOffset: -90,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: context.vd.ink),
                        ),
                        Text('môn',
                            style: TextStyle(
                                fontSize: 11, color: context.vd.inkMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Legend
              Expanded(
                child: Column(
                  children: entries.map((e) {
                    final color = _colorsOf(context.vd)[e.key] ?? context.vd.inkMuted;
                    final pct = (e.value / total * 100).round();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Loại ${e.key}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            '${e.value} môn · $pct%',
                            style: TextStyle(
                                fontSize: 11, color: context.vd.inkMuted),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
