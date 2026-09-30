import 'package:flutter/material.dart';

import '../../../screens/stale_note.dart';
import 'schedule_body.dart';
import '../../../theme/vd_tokens.dart';

/// "Lịch dạy hôm nay": stale note, retry button, title/date row with the
/// collapse toggle, then the [ScheduleBody].
class ScheduleSection extends StatelessWidget {
  final List<Map<String, dynamic>> classes;
  final bool loading;
  final bool failed;
  final bool expanded;
  final DateTime? staleAt;
  final VoidCallback onToggle;
  final VoidCallback onRetry;
  const ScheduleSection({
    super.key,
    required this.classes,
    required this.loading,
    required this.failed,
    required this.expanded,
    required this.staleAt,
    required this.onToggle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = [
      '',
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'Chủ nhật',
    ];
    final dateLabel =
        '${weekdays[now.weekday]}, ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (staleAt != null) StaleNote(staleAt!),
        if (failed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.wifi_off),
              label: const Text('Không có kết nối. Thử tải lịch lại'),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: context.vd.primary,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Lịch dạy hôm nay',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.vd.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onToggle(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.vd.accentSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        expanded ? 'Thu gọn' : 'Mở rộng',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.vd.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: context.vd.primary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ScheduleBody(
          classes: classes,
          loading: loading,
          failed: failed,
          expanded: expanded,
        ),
      ],
    );
  }
}
