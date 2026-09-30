import 'package:flutter/material.dart';
import '../grade_item.dart';
import 'grades_colors.dart';

// ── Detail Tab ───────────────────────────────────────────
class DetailTab extends StatelessWidget {
  final List<GradeItem> grades;
  const DetailTab({super.key, required this.grades});

  @override
  Widget build(BuildContext context) {
    if (grades.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('Chưa có điểm', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: grades.length,
      itemBuilder: (context, i) => GradeCard(item: grades[i]),
    );
  }
}

class GradeCard extends StatelessWidget {
  final GradeItem item;
  const GradeCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final color = gradeLetterColor(item.grade.gradeLetter);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Thanh màu trái
          Container(
            width: 5,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.mhten,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.school_outlined,
                          size: 12, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Text('${item.sotinchi} TC',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 12),
                      const Icon(Icons.tag,
                          size: 12, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Text(item.mhma,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      if (item.solan > 1) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(0xFFE65100).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Lần ${item.solan}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFE65100),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Điểm
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.diemchu,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.tongdiem.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color),
                ),
                // Text(
                //   '${item.diem4.toStringAsFixed(0)}/4',
                //   style: const TextStyle(
                //       fontSize: 11, color: Colors.grey),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
