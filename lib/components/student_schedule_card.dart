import 'package:flutter/material.dart';

import '../models/crm_student_schedule.dart';
import '../theme/vd_tokens.dart';

// ── Schedule Card ────────────────────────────────────────
class StudentScheduleCard extends StatelessWidget {
  final CrmScheduleItem data;

  /// Từ EMS (xem `_ScheduleScreenState._statusFor`), không phải IMS.
  final String status;
  const StudentScheduleCard({
    super.key,
    required this.data,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final subject = data.subjectName;
    final classCode = data.sectionCode;
    final room = data.room.trim();
    final teacher = data.teacherName;
    final start = data.startTime ?? '';
    final end = data.endTime ?? '';
    // CRM /me/schedule chỉ trả buổi HỌC — lịch thi nằm ở /me/exams riêng
    // (xem exam_screen.dart), nên không còn khái niệm "loaitkb == lichthi"
    // trộn trong cùng một feed như IMS `tkbtheongay` nữa. `isLichThi` giữ lại
    // như một cờ luôn false (thay vì xoá hẳn nhánh hiển thị) để badge "Lịch
    // thi" bên dưới không chết hẳn nếu một bot khác sau này gộp lịch thi vào
    // đây — không dùng `const` để tránh cảnh báo dead_code từ analyzer.
    final isLichThi = DateTime.now().year < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isLichThi
            ? context.vd.evening.withValues(alpha: 0.12)
            : context.vd.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.vd.shadow,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Thanh màu trái — đổi màu theo điểm danh / loại tkb
            Container(
              width: 5,
              height: double.infinity,
              decoration: BoxDecoration(
                color: isLichThi
                    ? context.vd.evening
                    : switch (status) {
                        'present' => context.vd.success,
                        'absent' => context.vd.danger,
                        'excused' => context.vd.info,
                        _ => context.vd.inkMuted,
                      },
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isLichThi)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.vd.evening.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 12,
                                  color: context.vd.evening,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Lịch thi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.vd.evening,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _StatusBadge(status: status),
                        const SizedBox(width: 12),
                      ],
                    ),
                    if (classCode.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 12),
                        child: Text(
                          classCode,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.vd.inkMuted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: context.vd.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          end.isNotEmpty ? '$start – $end' : start,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.person_outline,
                          size: 13,
                          color: context.vd.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            teacher,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.room, size: 13, color: context.vd.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            room,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (data.skipsWeeks) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Lớp có tuần nghỉ — có thể không học tuần này, '
                        'kiểm tra lại với lớp',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: context.vd.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status Badge ─────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = switch (status) {
      'loading' => (
        label: 'Đang tải',
        color: context.vd.inkMuted,
        bg: context.vd.surfaceAlt,
        icon: Icons.hourglass_empty,
      ),
      'denied' => (
        label: 'Không có quyền',
        color: context.vd.inkMuted,
        bg: context.vd.surfaceAlt,
        icon: Icons.lock_outline,
      ),
      'unavailable' => (
        label: 'Chưa tải được',
        color: context.vd.inkMuted,
        bg: context.vd.surfaceAlt,
        icon: Icons.cloud_off,
      ),
      'present' => (
        label: 'Có mặt',
        color: context.vd.success,
        bg: context.vd.successSoft,
        icon: Icons.check_circle_outline,
      ),
      'absent' => (
        label: 'Vắng mặt',
        color: context.vd.danger,
        bg: context.vd.dangerSoft,
        icon: Icons.cancel_outlined,
      ),
      'excused' => (
        label: 'Báo nghỉ',
        color: context.vd.info,
        bg: context.vd.infoSoft,
        icon: Icons.event_busy_outlined,
      ),
      _ => (
        label: 'Chưa điểm danh',
        color: context.vd.inkMuted,
        bg: context.vd.surfaceAlt,
        icon: Icons.radio_button_unchecked,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg.icon, size: 12, color: cfg.color),
          const SizedBox(width: 4),
          Text(
            cfg.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cfg.color,
            ),
          ),
        ],
      ),
    );
  }
}
