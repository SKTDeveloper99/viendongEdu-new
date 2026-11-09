import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/core/schedule/unmarked_session.dart';
import 'package:viendongedu2_flutter/features/classes/class_models.dart';
import 'package:viendongedu2_flutter/features/classes/widgets/attendance_card.dart';
import 'package:viendongedu2_flutter/features/classes/widgets/session_list_card.dart';
import 'package:viendongedu2_flutter/screens/ems_attendance_student_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_tokens.dart';

final _today = DateTime(2026, 11, 10, 9);

Widget _wrap(Widget w) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: w)),
);

void main() {
  test('one date rule: later = Sắp tới, today = Chờ, earlier = no data', () {
    expect(
      unmarkedSessionOn(DateTime(2026, 11, 11), _today),
      UnmarkedSession.upcoming,
    );
    expect(
      unmarkedSessionOn(DateTime(2026, 11, 10, 23), _today),
      UnmarkedSession.awaiting,
    );
    expect(
      unmarkedSessionOn(DateTime(2026, 11, 9), _today),
      UnmarkedSession.noData,
    );
    expect(UnmarkedSession.upcoming.label, 'Sắp tới');
    expect(UnmarkedSession.awaiting.label, 'Chờ điểm danh');
    expect(UnmarkedSession.noData.label, 'Chưa có dữ liệu');
    expect(sessionDay('2026-03-16T00:00:00.000Z'), DateTime(2026, 3, 16));
    expect(sessionDay('16/03/2026'), isNull);
  });

  const sessions = [
    AttendanceSession(ngay: '2026-11-02', hiendien: true, baonghi: false),
    AttendanceSession(ngay: '2026-11-03', hiendien: false, baonghi: false),
    AttendanceSession(ngay: '2026-11-04', hiendien: null, baonghi: false),
    AttendanceSession(ngay: '2026-11-10', hiendien: null, baonghi: false),
    AttendanceSession(ngay: '2026-11-17', hiendien: null, baonghi: false),
  ];

  testWidgets('class detail rows: Sắp tới, Chờ điểm danh, Chưa có dữ liệu', (
    t,
  ) async {
    await t.pumpWidget(_wrap(SessionListCard(sessions: sessions, now: _today)));
    expect(find.text('Có mặt'), findsOneWidget);
    expect(find.text('Vắng'), findsOneWidget);
    expect(find.text('Chưa có dữ liệu'), findsOneWidget);
    expect(find.text('Chờ điểm danh'), findsOneWidget);
    expect(find.text('Sắp tới'), findsOneWidget);
    expect(find.text('Chưa điểm danh'), findsNothing);
    // "Chưa có dữ liệu" is never drawn in the absent colour.
    final ctx = t.element(find.text('Chưa có dữ liệu'));
    final noData = t.widget<Text>(find.text('Chưa có dữ liệu'));
    expect(noData.style!.color, isNot(ctx.vd.danger));
  });

  testWidgets('chart: % of sessions with an outcome; unknown is not absent', (
    t,
  ) async {
    await t.pumpWidget(
      _wrap(
        const AttendanceCard(
          total: 5,
          present: 1,
          absent: 1,
          awaiting: 1,
          upcoming: 1,
          noData: 1,
        ),
      ),
    );
    expect(find.text('50%'), findsOneWidget); // 1 of 2 decided, not 1 of 5
    expect(find.text('Vắng'), findsOneWidget);
    expect(find.text('1  (50%)'), findsNWidgets(2)); // Có mặt + Vắng
    expect(find.text('Chưa có dữ liệu'), findsOneWidget);
    expect(find.text('Chờ điểm danh'), findsOneWidget);
    expect(find.text('Sắp tới'), findsOneWidget);
    expect(find.text('Chưa điểm danh'), findsNothing);
  });

  testWidgets('chart with no outcome yet shows — instead of 0%', (t) async {
    await t.pumpWidget(
      _wrap(const AttendanceCard(total: 2, present: 0, absent: 0, noData: 2)),
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('Điểm danh screen: title, Chờ giảng viên, rows by date', (
    t,
  ) async {
    AppSession.instance.emsToken = 'test-token';
    Map<String, dynamic> row(String date) => {
      'session_date': date,
      'subject_name': 'Môn thử nghiệm $date',
      'status': null,
    };
    EmsApiService.client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'marks': [
            row('2026-11-17'),
            row('2026-11-10'),
            row('2026-11-03'),
            {
              'session_date': '2026-11-02',
              'subject_name': 'Môn thử nghiệm vắng',
              'status': 'absent',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    addTearDown(() => EmsApiService.client = http.Client());
    await t.pumpWidget(
      MaterialApp(home: EmsAttendanceStudentScreen(now: () => _today)),
    );
    await t.pumpAndSettle();
    expect(find.text('Điểm danh'), findsOneWidget);
    expect(find.textContaining('EMS'), findsNothing);
    expect(find.text('Chờ giảng viên'), findsOneWidget);
    expect(find.text('Chờ GV'), findsNothing);
    expect(find.textContaining('• Sắp tới'), findsOneWidget);
    expect(find.textContaining('• Chờ giảng viên xác nhận'), findsOneWidget);
    expect(find.textContaining('• Chưa có dữ liệu'), findsOneWidget);
    expect(find.text('Chưa có dữ liệu'), findsOneWidget); // its own stat
  });
}
