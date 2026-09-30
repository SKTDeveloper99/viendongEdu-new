import 'package:flutter/material.dart';

import '../class_detail_sheet_view_model.dart';
import '../class_manager_format.dart';
import '../class_manager_models.dart';

/// Colour of an attendance progress bar (thresholds unchanged).
Color attendanceBarColor(double pct) => pct >= 0.8
    ? const Color(0xFF4CAF50)
    : pct >= 0.5
    ? const Color(0xFFFF9800)
    : Colors.red;

/// "Buổi học" list: one card per session with its EMS / CRM present count.
class AttendanceSessionList extends StatelessWidget {
  final ClassDetailSheetViewModel vm;
  final ValueChanged<SessionGroup> onOpen;
  const AttendanceSessionList({
    super.key,
    required this.vm,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final sessions = vm.sessions;
    if (sessions.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có buổi điểm danh',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final b = sessions[i];
        return _SessionCard(
          session: b,
          summary: vm.summaryOf(b),
          onTap: () => onOpen(b),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionGroup session;
  final SessionRowSummary summary;
  final VoidCallback onTap;
  const _SessionCard({
    required this.session,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = session;
    final marked = summary.marked;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 13,
                        color: Color(0xFFE65100),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        fmtDate(b.date),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${b.startTime ?? ''} – ${fmtTime(b.endTime)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.countText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF444444),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: summary.pct,
                      minHeight: 5,
                      backgroundColor: Colors.grey[200],
                      color: attendanceBarColor(summary.pct),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: marked
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                marked ? 'Đã ĐD' : 'Chưa ĐD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: marked ? const Color(0xFF4CAF50) : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
