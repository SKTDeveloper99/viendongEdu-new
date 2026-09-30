import 'package:flutter/material.dart';

import '../class_models.dart';

/// "Chi tiết các buổi học": one row per attendance session, oldest first.
class SessionListCard extends StatelessWidget {
  final List<AttendanceSession> sessions;
  const SessionListCard({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chi tiết các buổi học',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (var i = 0; i < sessions.length; i++) _row(i, sessions[i]),
        ],
      ),
    );
  }

  Widget _row(int i, AttendanceSession s) {
    final ngay = s.date;
    final dateStr = ngay != null
        ? '${ngay.day.toString().padLeft(2, '0')}/${ngay.month.toString().padLeft(2, '0')}/${ngay.year}'
        : '';

    final (label, color, bg, icon) = s.hiendien == true
        ? ('Có mặt', const Color(0xFF4CAF50), const Color(0xFFE8F5E9), Icons.check_circle_outline)
        : s.hiendien == false
            ? ('Vắng mặt', const Color(0xFFF44336), const Color(0xFFFFEBEE), Icons.cancel_outlined)
            : s.baonghi
                ? ('Báo nghỉ', const Color(0xFFE65100), const Color(0xFFFFF3E0), Icons.event_busy_outlined)
                : ('Chưa điểm danh', const Color(0xFF9E9E9E), const Color(0xFFF5F5F5), Icons.radio_button_unchecked);

    return Column(
      children: [
        if (i > 0) const Divider(height: 1, color: Color(0xFFF0F0F0)),
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
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 12, color: Color(0xFFE65100)),
                        const SizedBox(width: 4),
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
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
