import 'package:flutter/material.dart';

import '../../../data/class_manager_repository.dart';
import '../class_detail_sheet_view_model.dart';
import 'attendance_session_list.dart';
import 'attendance_summary_list.dart';
import 'class_manager_state_views.dart';
import 'session_detail_sheet.dart';
import '../../../theme/vd_tokens.dart';

/// "Điểm danh" tab: sub-tabs "Buổi học" (sessions) and "Tổng hợp" (per
/// student). Numbers are shown exactly as the view model hands them over.
class ClassAttendanceTab extends StatelessWidget {
  final ClassDetailSheetViewModel vm;
  final ClassManagerRepository repository;
  const ClassAttendanceTab({
    super.key,
    required this.vm,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    if (vm.loadingAttendance) return const SheetLoading();
    final error = vm.attendanceError;
    if (error != null) {
      return SheetErrorView(message: error, onRetry: vm.loadAttendance);
    }
    return Column(
      children: [
        if (vm.lmhId == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.vd.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Không xác định được buổi trên EMS cho lớp này — chỉ hiện dữ liệu ghi nhận trên CRM.',
                style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: context.vd.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _SubTabBtn(
                  label: 'Buổi học',
                  selected: vm.subTab == 0,
                  onTap: () => vm.setSubTab(0),
                ),
                _SubTabBtn(
                  label: 'Tổng hợp',
                  selected: vm.subTab == 1,
                  onTap: () => vm.setSubTab(1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: vm.subTab == 0
              ? AttendanceSessionList(
                  vm: vm,
                  onOpen: (b) => showSessionDetailSheet(
                    context,
                    repository: repository,
                    session: b,
                    sessionKey: vm.sessionKeyOf(b),
                  ),
                )
              : AttendanceSummaryList(totals: vm.totals),
        ),
      ],
    );
  }
}

class _SubTabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SubTabBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? context.vd.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? context.vd.onPrimary : context.vd.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
