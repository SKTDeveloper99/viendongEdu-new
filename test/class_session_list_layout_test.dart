import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/data/class_manager_repository.dart';
import 'package:viendongedu2_flutter/features/class_manager/class_detail_sheet_view_model.dart';
import 'package:viendongedu2_flutter/features/class_manager/class_manager_format.dart';
import 'package:viendongedu2_flutter/features/class_manager/widgets/attendance_session_list.dart';
import 'package:viendongedu2_flutter/models/crm_teacher_class.dart';
import 'package:viendongedu2_flutter/theme/vd_tokens.dart';

class _Repo extends ClassManagerRepository {
  @override
  Future<CrmAttendanceResult> attendanceResult(String sectionId) async =>
      const CrmAttendanceResult(
        plan: CrmClassPlan(
          totalSessions: 14,
          doneSessions: 3,
          lastDate: '2026-12-21',
          plannedPeriods: 60,
          requiredPeriods: 45,
          periodsMismatch: true,
        ),
        rows: [
          CrmAttendanceRow(
            sessionId: 's1',
            date: '2026-09-21',
            startTime: '13:00:00',
            endTime: '16:15:00',
            mssv: 'TEST260001',
            fullName: 'An Thử Nghiệm',
            status: 'present',
          ),
          CrmAttendanceRow(
            sessionId: 'planned:2026-09-28',
            date: '2026-09-28',
            startTime: '13:00:00',
            endTime: '16:15:00',
            sessionStatus: 'planned',
          ),
        ],
      );
}

void main() {
  test('fmtTime drops seconds', () {
    expect(fmtTime('13:00:00'), '13:00');
    expect(fmtTime('13:00'), '13:00');
    expect(fmtTime('2026-09-21T13:05:00.000'), '13:05');
    expect(fmtTime(null), '');
  });

  for (final w in [360.0, 402.0, 430.0]) {
    testWidgets('session list does not overflow at ${w.toInt()}pt', (
      tester,
    ) async {
      final vm = ClassDetailSheetViewModel(
        _Repo(),
        lop: const CrmTeacherClass(
          sectionId: 'sec',
          sectionCode: 'TN261A',
          subjectCode: 'TN101',
          subjectName: 'Môn thử nghiệm',
          enrolledStudents: 30,
        ),
        lmhId: null,
        now: () => DateTime.utc(2026, 12, 1),
      );
      await vm.loadAttendance();
      tester.view.physicalSize = Size(w, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [VdTokens.light]),
          home: Scaffold(
            body: AttendanceSessionList(vm: vm, onOpen: (_) {}),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text('Đã dạy 3/14 buổi · Kết thúc 21/12/2026'),
        findsOneWidget,
      );
      expect(find.textContaining('kiểm tra với PĐT'), findsOneWidget);
      expect(find.text('13:00 – 16:15'), findsNWidgets(2));
      expect(find.text('Sắp tới'), findsOneWidget);
    });
  }
}
