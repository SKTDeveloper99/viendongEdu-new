import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/teacher_attendance_repository.dart';
import '../../services/ems_api_service.dart';
import 'attendance_outbox.dart';
import 'roster_view_model.dart';
import 'widgets/attendance_message.dart';
import 'widgets/reasons_dialog.dart';
import 'widgets/roster_bottom_bar.dart';
import 'widgets/roster_quick_actions.dart';
import 'widgets/student_detail_sheet.dart';
import 'widgets/student_row.dart';
import 'widgets/unmarked_confirm_dialog.dart';
import '../../theme/vd_tokens.dart';

/// Roster of one session. Layout, dialogs and snackbars only; the marks, the
/// offline draft and the save flow live in [RosterViewModel].
class TeacherRosterScreen extends StatefulWidget {
  final TeacherAttendanceRepository repository;
  final EmsSession session;
  const TeacherRosterScreen({
    super.key,
    required this.repository,
    required this.session,
  });

  @override
  State<TeacherRosterScreen> createState() => _TeacherRosterScreenState();
}

class _TeacherRosterScreenState extends State<TeacherRosterScreen> {
  late final RosterViewModel _vm = RosterViewModel(
    widget.repository,
    widget.session,
    outbox: AttendanceOutbox.instance,
  );

  late final RosterPrompts _prompts = RosterPrompts(
    confirmUnmarked: (undecided, chosen) => showUnmarkedConfirmDialog(
      context,
      undecided: undecided,
      chosen: chosen,
    ),
    askReasons: (people, initial, nameOf) => showReasonsDialog(
      context,
      people: people,
      initial: initial,
      nameOf: nameOf,
    ),
    toast: _toast,
  );

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool good = false}) {
    if (!mounted) return;
    if (good) HapticFeedback.mediumImpact(); // only the successful-save toast
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: good ? context.vd.success : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        backgroundColor: context.vd.bg,
        appBar: AppBar(
          backgroundColor: context.vd.primary,
          foregroundColor: context.vd.onPrimary,
          title: Text(
            widget.session.subjectName?.isNotEmpty == true
                ? widget.session.subjectName!
                : widget.session.sectionCode,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            IconButton(
              tooltip: _vm.sortAz ? 'Thứ tự danh sách lớp' : 'Xếp tên A–Z',
              onPressed: _vm.toggleSort,
              icon: Icon(
                Icons.sort_by_alpha,
                color: _vm.sortAz
                    ? context.vd.onPrimary
                    : context.vd.onPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: _vm.loading || _vm.error != null
            ? null
            : RosterBottomBar(
                queued: _vm.queued,
                needsReasonCount: _vm.needsReason?.length,
                presentCount: _vm.presentCount,
                lateCount: _vm.lateCount,
                excusedCount: _vm.excusedCount,
                absentCount: _vm.absentCount,
                unmarkedCount: _vm.unmarkedCount,
                saving: _vm.saving,
                onSave: () => _vm.save(_prompts),
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_vm.loading) return const Center(child: CircularProgressIndicator());
    final error = _vm.error;
    if (error != null) {
      return AttendanceMessage(
        icon: Icons.cloud_off,
        title: 'Không tải được danh sách lớp',
        detail: error,
        onRetry: _vm.load,
      );
    }
    final students = _vm.students;
    final visible = _vm.visibleStudents;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: students.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) => i == 0
          ? RosterQuickActions(
              needsReview: _vm.needsReview,
              scanSyncedAt: _vm.scanSyncedAt,
              scannedCount: _vm.scannedCount,
              unscannedCount: _vm.unscannedCount,
              rosterSize: students.length,
              scansPending: _vm.scansPending,
              allPresent: _vm.allPresent,
              onMarkScannedPresent: _vm.markScannedPresent,
              onMarkAllPresent: _vm.markAllPresent,
              onResetToScanned: _vm.resetToScanned,
            )
          : _row(visible[i - 1]),
    );
  }

  Widget _row(EmsRosterStudent s) => StudentRow(
    student: s,
    mark: _vm.markOf(s.mssv),
    onSelect: (status) => _vm.select(s.mssv, status),
    onOpenDetail: () => showStudentDetailSheet(
      context,
      student: s,
      mark: _vm.markOf(s.mssv),
      scanSyncedAt: _vm.scanSyncedAt,
    ),
  );
}
