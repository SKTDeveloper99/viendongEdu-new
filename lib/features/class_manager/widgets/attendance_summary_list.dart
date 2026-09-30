import 'package:flutter/material.dart';

import '../class_manager_models.dart';
import 'attendance_session_list.dart';
import '../../../theme/vd_tokens.dart';

/// "Tổng hợp" list: present / total per student (CRM rows).
class AttendanceSummaryList extends StatelessWidget {
  final List<StudentAttendanceTotal> totals;
  const AttendanceSummaryList({super.key, required this.totals});

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) {
      return Center(
        child: Text('Chưa có dữ liệu', style: TextStyle(color: context.vd.inkMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: totals.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: context.vd.hairline),
      itemBuilder: (_, i) {
        final t = totals[i];
        final pct = t.total > 0 ? t.present / t.total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: context.vd.accentSoft,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: context.vd.primary,
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
                      style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4,
                        backgroundColor: context.vd.surfaceAlt,
                        color: attendanceBarColor(pct, context.vd),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${t.present}/${t.total}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: context.vd.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
