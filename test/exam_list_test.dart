// T3: exam-morning list. Status only, never an amount. Fixtures fictional.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/data/exam_list_repository.dart';
import 'package:viendongedu2_flutter/features/exam_list/exam_list_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_home/widgets/menu_grid.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/models/exam_status_models.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

// Shape of today's web endpoint, figures included (the app must drop them).
final _examMoney = {
  'section_id': 'sec-1',
  'semester_code': '261',
  'as_of': '2026-11-10T01:00:00.000Z',
  'stale': false,
  'students': [
    {
      'mssv': 'TEST2600001',
      'full_name': 'Học Viên Thử A',
      'status': 'no',
      'ims_balance': 1234567,
      'semesters': [
        {'semester_code': '261', 'net_owed': 1234567, 'typed_charge': 9},
        {'semester_code': '252', 'net_owed': 10, 'paid': 3},
      ],
    },
    {
      'mssv': 'TEST2600002',
      'full_name': 'Học Viên Thử B',
      'status': 'het_no',
      'ims_balance': 0,
    },
    {
      'mssv': 'TEST2600003',
      'full_name': 'Học Viên Thử C',
      'status': 'khong_co_du_lieu',
      'money_one': {'balance': 77, 'money_known': false},
    },
    {'mssv': 'TEST2600004', 'full_name': 'Học Viên Thử D', 'status': 'du'},
  ],
};

void main() {
  late bool offline;
  late List<Uri> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..emsToken = 'test-teacher-token'
      ..role = CrmRole.teacher
      ..teacherId = 'T-TEST-1';
    offline = false;
    calls = [];
    EmsApiService.client = MockClient((req) async {
      calls.add(req.url);
      if (offline) throw http.ClientException('test-offline');
      if (req.url.path.endsWith('/exam-money')) {
        return http.Response(jsonEncode(_examMoney), 200, headers: _json);
      }
      return http.Response(
        jsonEncode({
          'classes': [
            {
              'section_id': 'sec-1',
              'section_code': 'TN-LOP-1',
              'subject_name': 'Môn thi ngày mai',
              'ngay_thi': '2026-11-11',
            },
            {
              'section_id': 'sec-2',
              'section_code': 'TN-LOP-2',
              'subject_name': 'Môn đã thi',
              'ngay_thi': '2026-11-01',
            },
            {
              'section_id': 'sec-3',
              'section_code': 'TN-LOP-3',
              'subject_name': 'Môn thi hôm nay',
              'ngay_thi': '2026-11-10T00:00:00+07:00',
            },
            {'section_id': 'sec-4', 'section_code': 'TN-LOP-4'},
          ],
        }),
        200,
        headers: _json,
      );
    });
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..teacherId = null;
  });

  test('parse keeps status and semester codes, drops every figure', () {
    final r = ExamRosterStatus.fromJson(_examMoney);
    expect(r.students.map((s) => s.label), [
      'Còn nợ HK 261, 252',
      'Được thi',
      'Chưa có dữ liệu',
      'Được thi',
    ]);
    final stored = jsonEncode(r.toJson());
    for (final banned in ['1234567', 'balance', 'net_owed', 'money', '77']) {
      expect(stored.contains(banned), isFalse, reason: banned);
    }
    expect(r.count(ExamMoneyStatus.allowed), 2);
  });

  test('server status-only shape (ask A2) reads the same', () {
    final r = ExamRosterStatus.fromJson({
      'students': [
        {
          'mssv': 'X',
          'status': 'no',
          'owes_semesters': ['261'],
        },
      ],
    });
    expect(r.students.single.label, 'Còn nợ HK 261');
  });

  test('upcoming: from today, sorted, day never shifted', () async {
    final list = await const ExamListRepository().upcoming(
      DateTime(2026, 11, 10, 8),
    );
    expect(list.map((e) => e.klass.sectionCode), ['TN-LOP-3', 'TN-LOP-1']);
    expect(list.first.examDay, DateTime(2026, 11, 10));
  });

  testWidgets('list → class → one pill per student, status only', (t) async {
    await t.pumpWidget(
      MaterialApp(home: ExamListScreen(now: () => DateTime(2026, 11, 10, 8))),
    );
    await t.pumpAndSettle();
    expect(find.text('Danh sách thi'), findsOneWidget);
    expect(find.textContaining('Hôm nay'), findsOneWidget);
    expect(find.textContaining('Ngày mai'), findsOneWidget);
    expect(find.text('Môn đã thi'), findsNothing);
    await t.tap(find.text('Môn thi ngày mai'));
    await t.pumpAndSettle();
    expect(calls.last.queryParameters['view'], 'status');
    expect(find.text('Còn nợ HK 261, 252'), findsOneWidget);
    expect(find.text('Được thi'), findsNWidgets(2));
    expect(find.text('Chưa có dữ liệu'), findsOneWidget);
    expect(find.text('Theo quy định: vẫn được thi'), findsOneWidget);
    expect(
      find.text('2 được thi · 1 còn nợ · 1 chưa có dữ liệu'),
      findsOneWidget,
    );
    // No currency anywhere ("2 được thi" is fine; "1.000 đ" is not).
    expect(find.textContaining(RegExp(r'\d[\d.]* đ(\s|$)')), findsNothing);
    expect(find.textContaining('IMS'), findsNothing);
  });

  testWidgets('offline on exam morning: saved status copy, labelled', (
    t,
  ) async {
    await const ExamListRepository().roster('sec-1');
    offline = true;
    final saved = await const ExamListRepository().roster('sec-1');
    expect(saved.savedAt, isNotNull);
    expect(saved.students.first.label, 'Còn nợ HK 261, 252');
  });

  testWidgets('teacher home has the Danh sách thi tile', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: SingleChildScrollView(child: MenuGrid())),
        routes: {
          '/gv_danh_sach_thi': (_) => const Scaffold(body: Text('trang thi')),
        },
      ),
    );
    await t.tap(find.text('Danh sách thi'));
    await t.pumpAndSettle();
    expect(find.text('trang thi'), findsOneWidget);
  });
}
