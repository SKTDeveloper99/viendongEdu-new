import 'package:flutter/material.dart';

import '../student_home_view_model.dart';
import 'class_chip.dart';
import '../../../theme/vd_tokens.dart';

/// The state-dependent part of "Lịch học hôm nay": spinner, collapsed
/// summary, empty card, or the list of today's classes.
class ScheduleBody extends StatelessWidget {
  final StudentHomeViewModel vm;
  final bool scheduleExpanded;
  const ScheduleBody({
    super.key,
    required this.vm,
    required this.scheduleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final n = vm.todayClasses.length;
    final summaryText = vm.scheduleFailed
        ? 'Chưa tải được lịch học từ máy chủ'
        : n == 0
        ? 'Hôm nay bạn không có lịch học nào 🎉'
        : 'Hôm nay bạn có $n lịch học — nhấn để xem chi tiết';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (vm.scheduleLoading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.vd.primary,
                ),
              ),
            ),
          )
        else if (vm.scheduleFailed)
          const SizedBox.shrink()
        else if (!scheduleExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/schedule'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                    Icon(
                      n == 0 ? Icons.event_available : Icons.event_note,
                      size: 18,
                      color: n == 0 ? context.vd.success : context.vd.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: n == 0
                          ? Text(
                              summaryText,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.vd.inkMuted,
                              ),
                            )
                          : Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.vd.inkMuted,
                                ),
                                children: [
                                  const TextSpan(text: 'Hôm nay bạn có '),
                                  TextSpan(
                                    text: '$n',
                                    style: TextStyle(
                                      color: context.vd.danger,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' lịch học — nhấn để xem chi tiết',
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (vm.todayClasses.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  Icon(
                    Icons.event_available,
                    size: 18,
                    color: context.vd.success,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Không có lịch học hôm nay',
                    style: TextStyle(fontSize: 13, color: context.vd.inkMuted),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              children: vm.todayClasses
                  .map(
                    (d) => GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/schedule'),
                      child: ClassChip(data: d),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
