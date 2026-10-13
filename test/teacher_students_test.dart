// Teacher student view ("Sinh viên của tôi" → class → one student).
//
// Fixture is fictional (MSSV 25999xxxx, "Thử Nghiệm" names). The mock client
// answers the CRM student-care endpoints the screens read:
//   GET /api/student-care?limit=100&page=N   → students[] with dossier
//   GET /api/student-care/student/:mssv      → {available, student}
// Shape follows lib/student-care-service.js (crm-clean, LAW M-54).
//
//   flutter test test/teacher_students_test.dart
//
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/features/teacher_home/widgets/menu_grid.dart';
import 'package:viendongedu2_flutter/features/teacher_students/teacher_students_screen.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/models/teacher_care_student.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/crm_teacher_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/offline_snapshot.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _sec = 'aaaaaaaa-0000-0000-0000-000000000001';

Map<String, dynamic> _section({
  int present = 5,
  int absent = 0,
  int unrecorded = 0,
  Object? midterm = '7.50',
}) => {
  'section_id': _sec,
  'section_code': '25CDTHUNGHIEM1',
  'subject_name': 'Tin học thử nghiệm',
  'teacher_id': 'T-TEST-1',
  'present': present,
  'absent': absent,
  'unrecorded': unrecorded,
  'conflicts': 0,
  'ems_present': present,
  'ems_absent': absent,
  'midterm_score': midterm,
  'final_score': null,
};

Map<String, dynamic> _student(
  String mssv,
  String name, {
  Object? moneyOne,
  bool hasMoneyOne = true,
  Map<String, dynamic>? section,
  bool attendanceFresh = true,
  List<Map<String, dynamic>> checks = const [],
}) => {
  'mssv': mssv,
  'checks': checks,
  'can_review_sections': [_sec],
  'dossier': {
    'full_name': name,
    'class_code': '25CDTHUNGHIEM',
    'phone': '0900000000',
    'guardian_phone': '0911111111',
    'sections': [section ?? _section()],
    // Staff-only ledger: must never reach the teacher's screen.
    'money': {'status': 'no', 'ims_balance': 9999000, 'stale': false},
    'money_one': ?(hasMoneyOne ? moneyOne : null),
    'freshness': {
      'attendance': attendanceFresh,
      'grades': true,
      'academic': attendanceFresh,
    },
  },
};

Map<String, dynamic> _known({
  num owed = 4000000,
  num paid = 2500000,
  num balance = 1500000,
  bool owes = true,
}) => {
  'source': 'bang_ke',
  'money_known': true,
  'money_unknown_reason': null,
  'owedTotal': owed,
  'paid': paid,
  'balance': balance,
  'owes': owes,
  'payment_status': 'Cập nhật lúc 06:15 ngày 13/10',
};

const _unknownReason = 'Học phí của bạn đang được Phòng Kế toán đối chiếu.';

final _fixture = [
  // Owes; one session with no mark — not absent, not "cần chú ý".
  _student(
    '259990001',
    'An Thử Nghiệm',
    moneyOne: _known(),
    section: _section(unrecorded: 3),
  ),
  // Server before tonight's deploy: no money_one at all.
  _student('259990002', 'Bình Thử Nghiệm', hasMoneyOne: false),
  // Paid in full but absent twice → cần chú ý.
  _student(
    '259990003',
    'Châu Thử Nghiệm',
    moneyOne: _known(paid: 4000000, balance: 0, owes: false),
    section: _section(absent: 2),
  ),
  // Money not known yet + failed subject → cần chú ý.
  _student(
    '269990004',
    'Dũng Thử Nghiệm',
    moneyOne: {
      'source': 'bang_ke',
      'money_known': false,
      'money_unknown_code': 'bang_ke_chua_khai_bao',
      'money_unknown_reason': _unknownReason,
      'owedTotal': null,
      'paid': null,
      'balance': null,
      'payment_status': 'Cập nhật lúc 06:15 ngày 13/10',
    },
    attendanceFresh: false,
    checks: [
      {'kind': 'progression', 'title': 'Có môn chưa đạt'},
    ],
  ),
];

/// Words the teacher must never see (one voice: no sources, no ledgers).
final _forbidden = RegExp(
  r'bảng kê|bang_ke|IMS|CRM|Kế toán|theo sổ|basis|9\.999\.000|0900|0911',
  caseSensitive: false,
);

void main() {
  late Map<String, int> hits;
  late bool failNetwork;
  late int failStatus;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..emsToken = 'test-token'
      ..role = CrmRole.teacher
      ..teacherId = 'T-TEST-1'
      ..teacherCode = 'TESTGV01'
      ..fullName = 'Giảng Viên Thử Nghiệm';
    hits = {};
    failNetwork = false;
    failStatus = 500;
    EmsApiService.client = MockClient((req) async {
      final p = req.url.path;
      hits[p] = (hits[p] ?? 0) + 1;
      if (failNetwork) return http.Response('{"error":"boom"}', failStatus);
      if (p.endsWith('/student-care')) {
        return http.Response(
          jsonEncode({
            'students': _fixture,
            'page': 1,
            'limit': 100,
            'total': _fixture.length,
            'scope': 'own_students',
          }),
          200,
          headers: _json,
        );
      }
      if (p.contains('/student-care/student/')) {
        final mssv = p.split('/').last;
        final s = _fixture.firstWhere((e) => e['mssv'] == mssv);
        return http.Response(
          jsonEncode({'available': true, 'student': s, 'timeline': []}),
          200,
          headers: _json,
        );
      }
      return http.Response('{}', 404, headers: _json);
    });
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..teacherId = null
      ..teacherCode = null
      ..fullName = null;
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: TeacherStudentsScreen()));
    await tester.pumpAndSettle();
  }

  void expectOneVoice(WidgetTester tester) {
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final s = t.data ?? t.textSpan?.toPlainText() ?? '';
      expect(_forbidden.hasMatch(s), isFalse, reason: 'shown: "$s"');
    }
  }

  Future<void> openStudent(WidgetTester tester, String name) async {
    await tester.tap(find.text('Tin học thử nghiệm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  group('CareMoney (one number, never partial)', () {
    test('known only when all three figures are present', () {
      final m = CareMoney.fromJson(_known());
      expect(m.known, isTrue);
      expect(m.balance, 1500000);
      expect(m.owes, isTrue);
      expect(CareMoney.fromJson({..._known(), 'balance': null}).known, isFalse);
      expect(CareMoney.fromJson({..._known(), 'paid': 'x'}).known, isFalse);
      expect(
        CareMoney.fromJson({..._known(), 'money_known': false}).known,
        isFalse,
      );
      expect(CareMoney.fromJson(null).known, isFalse);
    });

    test('the staff ledger (dossier.money) is never read', () {
      final s = TeacherCareStudent.fromJson(
        _student('259990009', 'X', hasMoneyOne: false),
      );
      expect(s.money.known, isFalse);
      expect(s.money.owes, isFalse);
    });
  });

  testWidgets('level 1: counts of students and the class list', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Sinh viên của tôi'), findsOneWidget);
    expect(find.text('← Quay lại Trang chủ'), findsOneWidget);
    expect(find.text('Lớp của tôi'), findsOneWidget);
    // 1 owes (An); 2 need attention (Châu absent, Dũng failed subject).
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('4 sinh viên'), findsOneWidget);
    expectOneVoice(tester);
  });

  testWidgets('level 2: one small status per student, one voice', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Tin học thử nghiệm'));
    await tester.pumpAndSettle();
    expect(find.text('← Quay lại Sinh viên của tôi'), findsOneWidget);
    expect(find.text('Còn nợ học phí'), findsOneWidget);
    expect(find.text('Học phí: Đang đối chiếu'), findsNWidgets(2));
    expect(find.text('Cần chú ý'), findsNWidgets(2));
    expectOneVoice(tester);

    await tester.tap(find.text('← Quay lại Sinh viên của tôi'));
    await tester.pumpAndSettle();
    expect(find.text('Lớp của tôi'), findsOneWidget);
  });

  testWidgets('level 3: unknown money is exactly "Đang đối chiếu", no amount', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openStudent(tester, 'Dũng Thử Nghiệm');
    expect(find.text('← Quay lại Tin học thử nghiệm'), findsOneWidget);
    expect(find.text('Học phí'), findsOneWidget);
    expect(find.text('Đang đối chiếu'), findsWidgets);
    expect(find.textContaining(RegExp(r'\d đ')), findsNothing);
    expect(find.text(_unknownReason), findsNothing);
    // Stale attendance is not shown as numbers.
    expect(find.text('Có mặt'), findsNothing);
    expect(find.text('Có môn chưa đạt'), findsOneWidget);
    expectOneVoice(tester);
  });

  testWidgets('level 3: missing money_one (old server) → Đang đối chiếu', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openStudent(tester, 'Bình Thử Nghiệm');
    expect(find.text('Đang đối chiếu'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d đ')), findsNothing);
    expectOneVoice(tester);
  });

  testWidgets('level 3: known money, grades, null attendance not absent', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openStudent(tester, 'An Thử Nghiệm');
    expect(find.textContaining('Còn nợ học phí. Cần đóng'), findsOneWidget);
    expect(find.text('4.000.000 đ'), findsOneWidget);
    expect(find.text('2.500.000 đ'), findsOneWidget);
    expect(find.text('1.500.000 đ'), findsOneWidget);
    expect(find.text('7.5'), findsOneWidget);
    expect(find.text('Chưa có điểm'), findsOneWidget);
    expect(find.text('Chờ giáo viên xác nhận'), findsOneWidget);
    expect(find.text('3 buổi'), findsOneWidget);
    expect(find.text('0 buổi'), findsOneWidget); // Vắng
    expect(find.text('Cần chú ý'), findsNothing);
    expect(hits['/api/student-care/student/259990001'], 1);
    expectOneVoice(tester);
  });

  testWidgets('offline: shows the last good copy with its time', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pumpWidget(const SizedBox());
    failNetwork = true;
    await pumpScreen(tester);
    expect(find.textContaining('Chưa cập nhật được'), findsOneWidget);
    expect(find.text('Tin học thử nghiệm'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await openStudent(tester, 'An Thử Nghiệm');
    expect(find.text('1.500.000 đ'), findsOneWidget);
    expect(find.textContaining('Chưa cập nhật được'), findsOneWidget);
    expectOneVoice(tester);
  });

  testWidgets('offline with no saved copy: message and Thử lại', (
    tester,
  ) async {
    failNetwork = true;
    await pumpScreen(tester);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Lớp của tôi'), findsNothing);
  });

  test('401/403 are never masked by the saved copy', () async {
    await CrmTeacherApi.studentCare();
    failNetwork = true;
    failStatus = 403;
    await expectLater(
      CrmTeacherApi.studentCare(),
      throwsA(isA<EmsException>()),
    );
    expect(await OfflineSnapshot.load('teacher_student_care'), isNull);
    failNetwork = false;
    await CrmTeacherApi.studentCare();
    failNetwork = true;
    failStatus = 500;
    final r = await CrmTeacherApi.studentCare();
    expect(r.fresh, isFalse);
    expect(r.data, hasLength(4));
  });

  testWidgets('home menu has a "Sinh viên của tôi" tile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (_) => const Scaffold(body: MenuGrid()),
          '/gv_sinh_vien': (_) => const Scaffold(body: Text('route:sv')),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sinh viên của tôi'));
    await tester.pumpAndSettle();
    expect(find.text('route:sv'), findsOneWidget);
  });
}
