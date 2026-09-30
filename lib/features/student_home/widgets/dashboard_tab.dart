import 'package:flutter/material.dart';

import '../../../theme/vd_theme.dart';
import '../student_home_view_model.dart';
import 'board_card.dart';
import 'home_header.dart';
import 'menu_grid.dart';
import 'today_schedule.dart';

/// "Trang chủ" tab: header, today's schedule, board card and the menu grid.
class DashboardTab extends StatelessWidget {
  final StudentHomeViewModel vm;
  final bool scheduleExpanded;
  final VoidCallback onToggleExpanded;
  const DashboardTab({
    super.key,
    required this.vm,
    required this.scheduleExpanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HomeHeader(vm: vm),
        Expanded(
          child: RefreshIndicator(
            color: VdColors.terracotta,
            onRefresh: vm.loadTodaySchedule,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TodaySchedule(
                    vm: vm,
                    scheduleExpanded: scheduleExpanded,
                    onToggleExpanded: onToggleExpanded,
                  ),
                  BoardCard(vm: vm),
                  const MenuGrid(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
