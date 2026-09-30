import 'package:flutter/material.dart';

import '../class_manager_models.dart';
import 'attendance_session_list.dart';

/// "Tổng hợp" list: present / total per student (CRM rows).
class AttendanceSummaryList extends StatelessWidget {
  final List<StudentAttendanceTotal> totals;
  const AttendanceSummaryList({super.key, required this.totals});

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) {
      return const Center(
        child: Text('Chưa có dữ liệu', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: totals.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFF5F5F5)),
      itemBuilder: (_, i) {
        final t = totals[i];
        final pct = t.total > 0 ? t.present / t.total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE65100).withValues(alpha: 0.1),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.mssv,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4,
                        backgroundColor: Colors.grey[200],
                        color: attendanceBarColor(pct),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${t.present}/${t.total}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
