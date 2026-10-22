import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/components/student_schedule_card.dart';
import 'package:viendongedu2_flutter/components/unscheduled_subjects.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/screens/schedule_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

const _slot = {
  'section_code': 'TEST-SECTION-A',
  'subject_name': 'Môn thử nghiệm đã có lịch',
  'day_code': '4',
  'start_time': '07:30',
  'end_time': '09:30',
};
const _section = {
  'section_code': 'TEST-SECTION-B',
  'semester_code': '261',
  'subject_code': 'TEST-B',
  'subject_name': 'Môn thử nghiệm chưa có lịch',
};

Finder _subject(String name) => find.descendant(
  of: find.byType(UnscheduledSubjects),
  matching: find.text(name),
);

void main() {
  testWidgets(
    'permission denial is explicit and retry can load an empty timetable',
    (t) async {
      var denied = true;
      EmsApiService.client = MockClient(
        (_) async => http.Response(
          jsonEncode(
            denied
                ? {'error': 'Không có quyền xem lịch học.'}
                : {'schedule': [], 'marks': []},
          ),
          denied ? 403 : 200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await t.pumpWidget(
        MaterialApp(home: ScheduleScreen(now: () => DateTime(2026, 10, 23))),
      );
      await t.pumpAndSettle();
      expect(find.text('Không có quyền xem lịch học.'), findsOneWidget);
      expect(find.text('Đang đối chiếu'), findsNothing);
      denied = false;
      await t.tap(find.text('Thử lại'));
      await t.pumpAndSettle();
      expect(find.text('Không có lịch học'), findsOneWidget);
    },
  );
  late Map<String, dynamic> body;
  late bool offline;
  late int calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..emsToken = 'test-token'
      ..role = CrmRole.student
      ..mssv = 'TEST-STUDENT';
    body = {
      'schedule': [_slot],
      'chua_co_lich': [_section],
    };
    offline = false;
    calls = 0;
    EmsApiService.client = MockClient((req) async {
      expect(req.method, 'GET');
      if (req.url.path.endsWith('/student/me/schedule')) {
        calls++;
        if (offline) throw http.ClientException('offline');
        return http.Response(
          jsonEncode(body),
          200,
          headers: {
            'content-type': 'application/json',
            'etag': '"schedule-test"',
          },
        );
      }
      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..mssv = null;
  });

  Future<void> pump(
    WidgetTester t, {
    bool dark = false,
    double width = 390,
  }) async {
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: dark ? VdTheme.dark() : VdTheme.light(),
        home: ScheduleScreen(now: () => DateTime(2026, 9, 30, 7)),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> refresh(WidgetTester t) async {
    final list = find.descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(ListView),
    );
    await t.drag(list, const Offset(0, 350));
    await t.pumpAndSettle();
  }

  testWidgets(
    'S-38 subjects stay beside the timetable when selecting another day',
    (t) async {
      body['chua_co_lich'] = [
        _section,
        {
          ..._section,
          'section_code': 'TEST-C',
          'semester_code': '262',
          'subject_name': 'Môn thử nghiệm học kỳ khác',
        },
      ];
      await pump(t);
      expect(find.byType(StudentScheduleCard), findsOneWidget);
      expect(find.text('Môn chưa có lịch'), findsOneWidget);
      expect(_subject(_section['subject_name']!), findsOneWidget);
      expect(_subject('Môn thử nghiệm học kỳ khác'), findsOneWidget);
      expect(find.text('Chưa có lịch'), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(UnscheduledSubjects),
          matching: find.byType(StudentScheduleCard),
        ),
        findsNothing,
      );
      await t.tap(find.text('T5'));
      await t.pumpAndSettle();
      expect(find.byType(StudentScheduleCard), findsNothing);
      expect(find.text('Không có lịch học'), findsOneWidget);
      expect(find.text('Chưa có lịch'), findsNWidgets(2));
      expect(calls, 1);
      await t.tap(find.text('T4'));
      await t.pumpAndSettle();
      expect(find.byType(StudentScheduleCard), findsOneWidget);
      expect(find.text('Chưa có lịch'), findsNWidgets(2));
    },
  );

  for (final present in [false, true]) {
    testWidgets(
      'older server ${present ? 'empty' : 'missing'} field shows nothing',
      (t) async {
        if (present) {
          body['chua_co_lich'] = [];
        } else {
          body.remove('chua_co_lich');
        }
        await pump(t);
        expect(find.byType(UnscheduledSubjects), findsNothing);
        expect(find.text('Môn chưa có lịch'), findsNothing);
        expect(find.byType(StudentScheduleCard), findsOneWidget);
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets(
      'unscheduled-only day fits a narrow ${dark ? 'dark' : 'light'} screen',
      (t) async {
        body['schedule'] = [];
        body['chua_co_lich'] = [
          {
            ..._section,
            'subject_name':
                'Môn thử nghiệm có tên dài cần xuống dòng trên điện thoại nhỏ',
          },
        ];
        await pump(t, dark: dark, width: 320);
        expect(find.byType(StudentScheduleCard), findsNothing);
        expect(find.text('Môn chưa có lịch'), findsOneWidget);
        expect(find.text('Chưa có lịch'), findsOneWidget);
        expect(find.text('Không có lịch học'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('refresh publishes a subject and clears cached days', (t) async {
    await pump(t);
    await t.tap(find.text('T5'));
    await t.pumpAndSettle();
    body = {
      'schedule': [
        {..._slot, 'subject_name': 'Môn thử nghiệm cập nhật'},
        {
          ..._slot,
          'day_code': '5',
          'section_code': 'TEST-SECTION-B',
          'subject_name': _section['subject_name'],
        },
      ],
      'chua_co_lich': [],
    };
    await refresh(t);
    expect(calls, 2);
    expect(find.text('Môn chưa có lịch'), findsNothing);
    expect(find.byType(StudentScheduleCard), findsOneWidget);
    expect(find.text(_section['subject_name']!), findsOneWidget);
    await t.tap(find.text('T4'));
    await t.pumpAndSettle();
    expect(find.byType(StudentScheduleCard), findsOneWidget);
    expect(find.text('Môn thử nghiệm cập nhật'), findsOneWidget);
    expect(find.text('Môn thử nghiệm đã có lịch'), findsNothing);
    expect(calls, 2);
  });

  testWidgets('offline cached subjects carry the stale note', (t) async {
    await pump(t);
    offline = true;
    await refresh(t);
    expect(calls, 2);
    expect(_subject(_section['subject_name']!), findsOneWidget);
    expect(find.text('Chưa có lịch'), findsOneWidget);
    expect(
      find.textContaining('Chưa cập nhật được — dữ liệu lúc'),
      findsOneWidget,
    );
  });

  testWidgets('failed read is unknown, never an empty timetable claim', (
    t,
  ) async {
    offline = true;
    await pump(t);
    expect(find.textContaining('Không có kết nối Internet'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Không có lịch học'), findsNothing);
    expect(find.byType(UnscheduledSubjects), findsNothing);
  });
}
