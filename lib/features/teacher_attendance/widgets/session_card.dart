import 'package:flutter/material.dart';

import '../../../services/ems_api_service.dart';
import '../../../theme/vd_tokens.dart';

/// One of today's sessions: subject, section, time, roster size, room and
/// the "Đã gửi / Đã chốt" badge.
class SessionCard extends StatelessWidget {
  const SessionCard({super.key, required this.session, required this.onTap});

  final EmsSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Material(
      color: context.vd.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.subjectName?.isNotEmpty == true
                          ? s.subjectName!
                          : s.sectionCode,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (s.isMarked || s.reportState != 'open')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.vd.successSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s.reportState == 'final'
                            ? 'Đã chốt ${s.markedCount}'
                            : 'Đã gửi ${s.markedCount}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.vd.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.sectionCode,
                style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: context.vd.inkMuted),
                  const SizedBox(width: 4),
                  Text(
                    s.timeLabel,
                    style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.groups, size: 14, color: context.vd.inkMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${s.rosterSize}',
                    style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
                  ),
                  if (s.room?.isNotEmpty == true) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.place, size: 14, color: context.vd.inkMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        s.room!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
