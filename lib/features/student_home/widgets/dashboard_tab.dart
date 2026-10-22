import 'package:flutter/material.dart';

import '../../../core/lantern_gate.dart';

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
    // Lantern gate: MSSV below the release prefix sees no schedule data.
    final dataOpen = studentDataOpen(vm.mssv == '–' ? null : vm.mssv);
    return Column(
      children: [
        HomeHeader(vm: vm),
        if (vm.secondaryFailed) TextButton(
          onPressed: vm.refresh,
          child: const Text('Chưa cập nhật được thông tin. Thử lại'),
        ),
        Expanded(
          child: RefreshIndicator(
            color: context.vd.primary,
            onRefresh: vm.refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              // The QR button rises homeNavOverhang above the bar.
              padding: const EdgeInsets.only(bottom: homeNavOverhang + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dataOpen && !vm.scheduleLoading && !vm.scheduleFailed)
                    NextUpCard(state: vm.upNext, emptyText: studentNextUpEmpty),
                  if (dataOpen)
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
