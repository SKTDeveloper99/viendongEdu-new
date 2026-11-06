import 'package:flutter/material.dart';
import '../models/crm_student_exams.dart';
import '../theme/vd_tokens.dart';

/// Exam counterpart of StudentScheduleCard, without an attendance status.
class ScheduleExamCard extends StatelessWidget {
  final CrmStudentExam exam;
  final VoidCallback? onTap;
  const ScheduleExamCard({super.key, required this.exam, this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: context.vd.evening.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: context.vd.shadow,
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: context.vd.evening,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.vd.evening.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Lịch thi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.vd.evening,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      exam.subjectName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.vd.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${exam.examDateFormatted} · ${exam.startTime.isEmpty ? '—' : exam.startTime} · ${exam.durationMinutes == null ? '—' : '${exam.durationMinutes} phút'}',
                      style: TextStyle(fontSize: 12, color: context.vd.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Phòng: ${exam.room?.trim().isNotEmpty == true ? exam.room!.trim() : '—'}',
                      style: TextStyle(fontSize: 12, color: context.vd.ink),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
