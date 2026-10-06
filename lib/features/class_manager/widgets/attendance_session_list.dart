import 'package:flutter/material.dart';

import '../class_detail_sheet_view_model.dart';
import '../class_manager_models.dart';
import '../../../theme/vd_tokens.dart';
import 'attendance_session_card.dart';

/// Colour of an attendance progress bar (thresholds unchanged).
Color attendanceBarColor(double pct, VdTokens t) => pct >= 0.8
    ? t.success
    : pct >= 0.5
    ? t.accent
    : t.danger;

/// "Buổi học" list: one card per session with its EMS / CRM present count.
class AttendanceSessionList extends StatelessWidget {
  final ClassDetailSheetViewModel vm;
  final ValueChanged<SessionGroup> onOpen;
  const AttendanceSessionList({
    super.key,
    required this.vm,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final sessions = vm.sessions;
    if (sessions.isEmpty) {
      return Center(
        child: Text(
          'Chưa có buổi điểm danh',
          style: TextStyle(color: context.vd.inkMuted),
        ),
      );
    }
    final header = vm.planHeader;
    final note = vm.planMismatchNote;
    final offset = header == null ? 0 : 1;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: sessions.length + offset,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (header != null && i == 0) {
          return PlanHeader(header: header, note: note);
        }
        final b = sessions[i - offset];
        final summary = vm.summaryOf(b);
        return SessionCard(
          session: b,
          summary: summary,
          showNumber: header != null,
          // Planned sessions cannot be marked from here.
          onTap: summary.planned ? null : () => onOpen(b),
        );
      },
    );
  }
}
