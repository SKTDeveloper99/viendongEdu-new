import 'package:flutter/material.dart';

import '../teacher_home_view_model.dart';
import 'home_header.dart';
import 'menu_grid.dart';
import 'my_day_card.dart';
import 'schedule_section.dart';

/// Home tab: header, today's schedule, my-day card and the menu tiles.
class HomeTab extends StatelessWidget {
  final TeacherHomeViewModel vm;
  final bool scheduleExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onBell;
  const HomeTab({
    super.key,
    required this.vm,
    required this.scheduleExpanded,
    required this.onToggleExpanded,
    required this.onBell,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HomeHeader(
          name: vm.displayName,
          code: vm.teacherCode,
          isCoHuu: vm.profile?.isCoHuu == true,
          unreadCount: vm.unreadCount,
          onBell: onBell,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScheduleSection(
                  classes: vm.todayClasses,
                  loading: vm.scheduleLoading,
                  failed: vm.scheduleFailed,
                  expanded: scheduleExpanded,
                  staleAt: vm.scheduleStaleAt,
                  onToggle: onToggleExpanded,
                  onRetry: vm.loadOverview,
                ),
                const MyDayCard(),
                const MenuGrid(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
