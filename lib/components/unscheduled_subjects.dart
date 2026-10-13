import 'package:flutter/material.dart';

import '../models/crm_student_schedule.dart';
import '../theme/vd_tokens.dart';

/// S-38: shown beside the selected day's slots, without a day or attendance.
class UnscheduledSubjects extends StatelessWidget {
  final List<CrmUnscheduledSection> sections;

  const UnscheduledSubjects({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Môn chưa có lịch',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.vd.ink,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.vd.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (final section in sections)
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.event_busy_outlined,
                    size: 20,
                    color: context.vd.inkMuted,
                  ),
                  title: Text(
                    section.subjectName.trim().isEmpty
                        ? 'Đang đối chiếu'
                        : section.subjectName,
                  ),
                  subtitle: Text(
                    'Chưa có lịch',
                    style: TextStyle(color: context.vd.inkMuted),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
