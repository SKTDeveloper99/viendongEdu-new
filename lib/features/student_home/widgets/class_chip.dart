import 'package:flutter/material.dart';

import '../../../models/crm_student_schedule.dart';
import '../../../theme/vd_theme.dart';

// Buổi (sáng/chiều/tối) suy ra từ giờ bắt đầu — CRM /me/schedule không có
// trường `buoi` như IMS `tkbtheongay`, nên đây là quy ước hiển thị client-side
// (xem docs/ims_to_crm_student_academic_map.md), không phải dữ liệu server.
({String label, Color color}) buoiInfo(String? startTime) {
  if (startTime == null || startTime.isEmpty) {
    return (label: '', color: Colors.grey);
  }
  final hour = int.tryParse(startTime.split(':').first) ?? -1;
  if (hour < 0) return (label: '', color: Colors.grey);
  if (hour < 12) return (label: 'Sáng', color: const Color(0xFF2196F3));
  if (hour < 18) return (label: 'Chiều', color: const Color(0xFFFF9800));
  return (label: 'Tối', color: const Color(0xFF9C27B0));
}

/// One of today's classes: subject, Sáng/Chiều/Tối tag, time, teacher, room.
class ClassChip extends StatelessWidget {
  final CrmScheduleItem data;
  const ClassChip({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data.subjectName;
    final classCode = data.sectionCode;
    final room = data.room.trim();
    final teacher = data.teacherName;
    final start = data.startTime ?? '';
    final end = data.endTime ?? '';
    final buoi = buoiInfo(start);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
        border: Border(left: BorderSide(color: buoi.color, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (buoi.label.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: buoi.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      buoi.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: buoi.color,
                      ),
                    ),
                  ),
              ],
            ),
            if (classCode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  classCode,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF999999),
                  ),
                ),
              ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: buoi.color),
                const SizedBox(width: 3),
                Text(
                  end.isNotEmpty ? '$start – $end' : start,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: buoi.color,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.person_outline,
                  size: 12,
                  color: VdColors.terracotta,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    teacher,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.room, size: 12, color: VdColors.terracotta),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    room,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
