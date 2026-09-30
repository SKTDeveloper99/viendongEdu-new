import 'package:flutter/material.dart';

import '../student_home_view_model.dart';
import '../../../components/next_up_card.dart';
import '../next_up.dart';
import 'board_card.dart';
import 'home_bottom_nav.dart' show homeNavOverhang;
import 'home_header.dart';
import 'menu_grid.dart';
import 'today_schedule.dart';
import '../../../theme/vd_tokens.dart';

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
            color: context.vd.primary,
            onRefresh: vm.loadTodaySchedule,
            child: SingleChildScrollView(
              // The QR button rises homeNavOverhang above the bar.
              padding: const EdgeInsets.only(bottom: homeNavOverhang + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!vm.scheduleLoading && !vm.scheduleFailed)
                    NextUpCard(state: vm.upNext, emptyText: studentNextUpEmpty),
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
