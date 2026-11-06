import 'package:flutter/material.dart';

import '../class_manager_format.dart';
import '../class_manager_models.dart';
import '../../../theme/vd_tokens.dart';
import 'attendance_session_list.dart' show attendanceBarColor;

class PlanHeader extends StatelessWidget {
  final String header;
  final String? note;
  const PlanHeader({super.key, required this.header, this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              header,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.vd.ink,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(
                note!,
                style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SessionCard extends StatelessWidget {
  final SessionGroup session;
  final SessionRowSummary summary;
  final bool showNumber;
  final VoidCallback? onTap;
  const SessionCard({
    super.key,
    required this.session,
    required this.summary,
    required this.onTap,
    this.showNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = session;
    final marked = summary.marked;
    final planned = summary.planned;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: planned ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.vd.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: context.vd.shadow,
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
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 13,
                          color: context.vd.primary,
                        ),
                        if (showNumber && b.number > 0)
                          Text(
                            'Buổi ${b.number}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: context.vd.primary,
                            ),
                          ),
                        Text(
                          fmtDate(b.date),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${fmtTime(b.startTime)} – ${fmtTime(b.endTime)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.vd.inkMuted,
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
                            style: TextStyle(
                              fontSize: 13,
                              color: context.vd.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!planned) const SizedBox(height: 6),
                    if (!planned)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: summary.pct,
                          minHeight: 5,
                          backgroundColor: context.vd.surfaceAlt,
                          color: attendanceBarColor(summary.pct, context.vd),
                        ),
                      ),
                  ],
                ),
              ),
              if (!planned) const SizedBox(width: 10),
              if (!planned)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: marked
                        ? context.vd.success.withValues(alpha: 0.12)
                        : context.vd.inkMuted.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    marked ? 'Đã ĐD' : 'Chưa ĐD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: marked ? context.vd.success : context.vd.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
