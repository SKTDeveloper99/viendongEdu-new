import 'package:flutter/material.dart';

import '../class_models.dart';
import '../../../theme/vd_tokens.dart';

/// "Chi tiết các buổi học": one row per attendance session, oldest first.
class SessionListCard extends StatelessWidget {
  final List<AttendanceSession> sessions;
  const SessionListCard({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: context.vd.shadow, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chi tiết các buổi học',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (var i = 0; i < sessions.length; i++) _row(context, i, sessions[i]),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int i, AttendanceSession s) {
    final ngay = s.date;
    final dateStr = ngay != null
        ? '${ngay.day.toString().padLeft(2, '0')}/${ngay.month.toString().padLeft(2, '0')}/${ngay.year}'
        : '';

    final (label, color, bg, icon) = s.hiendien == true
        ? ('Có mặt', context.vd.success, context.vd.successSoft, Icons.check_circle_outline)
        : s.hiendien == false
            ? ('Vắng mặt', context.vd.danger, context.vd.dangerSoft, Icons.cancel_outlined)
            : s.baonghi
                ? ('Báo nghỉ', context.vd.primary, context.vd.accentSoft, Icons.event_busy_outlined)
                : ('Chưa điểm danh', context.vd.inkFaint, context.vd.surfaceAlt, Icons.radio_button_unchecked);

    return Column(
      children: [
        if (i > 0) Divider(height: 1, color: context.vd.hairline),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buổi ${i + 1}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.vd.inkMuted)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 12, color: context.vd.primary),
                        const SizedBox(width: 4),
                        Text(dateStr,
                            style: TextStyle(
                                fontSize: 12, color: context.vd.inkMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
