import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/core/school_calendar.dart';
import 'package:viendongedu2_flutter/data/teacher_home_repository.dart';
import 'package:viendongedu2_flutter/features/teacher_home/teacher_home_view_model.dart';
import 'package:viendongedu2_flutter/features/teacher_home/widgets/week_strip.dart';
import 'package:viendongedu2_flutter/screens/gv_schedule_screen.dart';
import 'package:viendongedu2_flutter/screens/teacher_my_day_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/crm_teacher_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

void main() {
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..teacherId = null;
  });

  test('school date follows HCMC across the Melbourne midnight boundary', () {
    // 01:30 in Melbourne (UTC+11), but still 21:30 on 4 Oct in HCMC.
    final before = SchoolCalendar(
      clock: () => DateTime.utc(2026, 10, 4, 14, 30),
    );
    expect(before.todayIso, '2026-10-04');

    // 00:30 in HCMC: the school calendar advances deterministically.
    final after = SchoolCalendar(
      clock: () => DateTime.utc(2026, 10, 4, 17, 30),
    );
    expect(after.todayIso, '2026-10-05');

    // A picker value is a calendar date, not an instant to convert.
    expect(
      SchoolCalendar.isoDate(SchoolCalendar.dateOnly(DateTime(2026, 10, 5))),
      '2026-10-05',
    );
  });

  test('teacher overview cache expires at the HCMC day boundary', () async {
    SharedPreferences.setMockInitialValues({});
    final session = AppSession.instance
      ..emsToken = 'test-token'
      ..role = CrmRole.teacher
      ..teacherId = 'TEST-GV';
    final scope = base64Url.encode(utf8.encode('${session.role}:TEST-GV'));
    final resource = base64Url.encode(utf8.encode('teacher_overview'));
    final key = 'offline_v1_${scope}_$resource';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        'saved_at': DateTime.utc(2026, 10, 4, 16, 30).toIso8601String(),
        'data': <String, Object>{},
      }),
    );

    final calendar = SchoolCalendar(
      clock: () => DateTime.utc(2026, 10, 4, 17, 30),
    );
    expect(await CrmTeacherApi.cachedOverview(calendar: calendar), isNull);
  });

  testWidgets(
    'teacher schedule uses school today and sends selected date verbatim',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final requested = <String>[];
      final calendar = SchoolCalendar(
        clock: () => DateTime.utc(2026, 10, 4, 14, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: VdTheme.light(),
          home: GvScheduleScreen(
            calendar: calendar,
            loadSchedule: (date) async {
              requested.add(date);
              return const [];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(requested, ['2026-10-04']);
      expect(
        find.byKey(const ValueKey('schedule-today-2026-10-04')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('schedule-day-2026-10-03')));
      await tester.pumpAndSettle();
      expect(requested, ['2026-10-04', '2026-10-03']);
    },
  );

  testWidgets('teacher home week strip takes its today from the school clock', (
    tester,
  ) async {
    final calendar = SchoolCalendar(
      clock: () => DateTime.utc(2026, 10, 4, 14, 30),
    );
    final vm = TeacherHomeViewModel(
      const TeacherHomeRepository(),
      now: () => calendar.now,
      tickEvery: null,
    );
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        home: Scaffold(
          body: WeekStrip(
            today: vm.today,
            selected: vm.selectedDay,
            dotStartsFor: (_) => const [],
            onSelect: (_) {},
          ),
        ),
      ),
    );

    expect(vm.today, DateTime(2026, 10, 4));
    expect(find.byKey(const ValueKey('week-day-2026-10-4')), findsOneWidget);
  });

  testWidgets("'Ngày làm việc của tôi' requests the HCMC school date", (
    tester,
  ) async {
    AppSession.instance.emsToken = 'test-token';
    EmsApiService.client = MockClient(
      (_) async => http.Response(
        jsonEncode({'cases': <Object>[]}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    String? requested;
    final calendar = SchoolCalendar(
      clock: () => DateTime.utc(2026, 10, 4, 14, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        home: TeacherMyDayScreen(
          calendar: calendar,
          loadSessions: ({date}) async {
            requested = date;
            return const [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requested, '2026-10-04');
  });
}
