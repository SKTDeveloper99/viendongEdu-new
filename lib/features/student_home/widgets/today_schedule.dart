import 'package:flutter/material.dart';

import '../../../screens/stale_note.dart';
import '../../../theme/vd_theme.dart';
import '../student_home_view_model.dart';
import 'schedule_body.dart';

/// "Lịch học hôm nay": stale note, retry, title row with collapse toggle and
/// the schedule body.
class TodaySchedule extends StatelessWidget {
  final StudentHomeViewModel vm;
  final bool scheduleExpanded;
  final VoidCallback onToggleExpanded;
  const TodaySchedule({
    super.key,
    required this.vm,
    required this.scheduleExpanded,
    required this.onToggleExpanded,
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
    final dayLabel = weekdays[now.weekday];
    final dateLabel =
        '$dayLabel, ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (vm.scheduleStaleAt != null) StaleNote(vm.scheduleStaleAt!),
        if (vm.scheduleFailed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: vm.loadTodaySchedule,
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
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: VdColors.terracotta,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Lịch học hôm nay',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onToggleExpanded(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: VdColors.terracotta.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        scheduleExpanded ? 'Thu gọn' : 'Mở rộng',
                        style: const TextStyle(
                          fontSize: 11,
                          color: VdColors.terracotta,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        scheduleExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: VdColors.terracotta,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        ScheduleBody(vm: vm, scheduleExpanded: scheduleExpanded),
      ],
    );
  }
}
