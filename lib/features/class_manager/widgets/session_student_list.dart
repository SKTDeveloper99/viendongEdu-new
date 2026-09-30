import 'package:flutter/material.dart';

import '../session_detail_view_model.dart';
import '../../../theme/vd_tokens.dart';

/// Students of one session with their EMS state (Có mặt / Vắng / Chưa điểm
/// danh).
class SessionStudentList extends StatelessWidget {
  final SessionDetailViewModel vm;
  const SessionStudentList({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final students = vm.students;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: students.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: context.vd.hairline),
      itemBuilder: (_, i) {
        final s = students[i];
        final presentState = vm.presentOf(s);
        final unmarked = presentState == null;
        final tone = unmarked
            ? context.vd.info
            : presentState
            ? context.vd.success
            : context.vd.danger;
        final label = unmarked
            ? 'Chưa điểm danh'
            : presentState
            ? 'Có mặt'
            : 'Vắng';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: tone.withValues(alpha: 0.1),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: tone,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.fullName ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.mssv ?? '',
                      style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
