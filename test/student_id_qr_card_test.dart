// Student-ID QR card on the student's "Cá nhân" tab: look-up only, built
// from the held sign-in identity, students only, nothing for an empty ID.
// Fictional data only.
//
//   flutter test test/student_id_qr_card_test.dart
//
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:viendongedu2_flutter/data/student_home_repository.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_view_model.dart';
import 'package:viendongedu2_flutter/features/student_home/widgets/profile_tab.dart';
import 'package:viendongedu2_flutter/features/student_home/widgets/student_id_qr_card.dart';
import 'package:viendongedu2_flutter/features/student_home/widgets/student_id_qr_view.dart';
import 'package:viendongedu2_flutter/features/teacher_home/widgets/profile_tab.dart'
    as teacher;
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

const _name = 'Nguyễn Văn Thử';
const _id = 'TEST26APP01';

final _card = find.byKey(const Key('student-id-qr-card'));
final _dialog = find.byKey(const Key('student-id-qr-dialog'));

void main() {
  late int netCalls;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'x',
      packageName: 'x',
      version: '9.9.9',
      buildNumber: '1',
      buildSignature: '',
    );
    netCalls = 0;
    // Any HTTP request from the app fails the "no network" check.
    EmsApiService.client = MockClient((_) async {
      netCalls++;
      return http.Response('{}', 500);
    });
  });

  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..mssv = null
      ..fullName = null;
  });

  void signIn(CrmRole role, {String? mssv}) => AppSession.instance
    ..emsToken = 'test-token'
    ..role = role
    ..mssv = mssv
    ..fullName = _name;

  Future<void> pumpStudentProfile(
    WidgetTester tester, {
    ThemeData? theme,
  }) async {
    final vm = StudentHomeViewModel(
      const StudentHomeRepository(),
      tickEvery: null,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? VdTheme.light(),
        home: Scaffold(
          body: ProfileTab(vm: vm, onLogout: () {}),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('student sees name, MSSV and a QR whose data is the MSSV', (
    tester,
  ) async {
    signIn(CrmRole.student, mssv: _id);
    await pumpStudentProfile(tester);

    expect(_card, findsOneWidget);
    expect(
      find.descendant(of: _card, matching: find.text(_name)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _card, matching: find.text('MSSV: $_id')),
      findsOneWidget,
    );
    final qr = tester.widget<StudentIdQrCode>(
      find.descendant(of: _card, matching: find.byType(StudentIdQrCode)),
    );
    expect(qr.data, _id);
    expect(
      find.descendant(of: _card, matching: find.byType(QrImageView)),
      findsOneWidget,
    );

    // Vietnamese semantic label and a tap target of at least 48 px.
    // (The card's button merges its children, so the label is part of it.)
    expect(
      tester
          .getSemantics(
            find.descendant(of: _card, matching: find.byType(StudentIdQrCode)),
          )
          .label,
      contains('Mã QR của mã số sinh viên $_id'),
    );
    expect(tester.getSize(_card).height, greaterThanOrEqualTo(48));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('tap opens the large QR, which can be closed', (tester) async {
    signIn(CrmRole.student, mssv: _id);
    await pumpStudentProfile(tester, theme: VdTheme.dark());

    await tester.tap(_card);
    await tester.pumpAndSettle();

    expect(_dialog, findsOneWidget);
    expect(
      tester
          .widget<StudentIdQrCode>(
            find.descendant(
              of: _dialog,
              matching: find.byType(StudentIdQrCode),
            ),
          )
          .data,
      _id,
    );
    expect(
      find.bySemanticsLabel('Mã QR của mã số sinh viên $_id'),
      findsOneWidget,
    );
    final big = tester.widget<QrImageView>(
      find.descendant(of: _dialog, matching: find.byType(QrImageView)),
    );
    // Dark modules on white even in dark mode.
    expect(big.backgroundColor, const Color(0xFFFFFFFF));
    expect(big.dataModuleStyle.color, const Color(0xFF000000));
    expect(big.eyeStyle.color, const Color(0xFF000000));
    expect(
      find.descendant(of: _dialog, matching: find.text(_name)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _dialog, matching: find.text('MSSV: $_id')),
      findsOneWidget,
    );

    final close = find.byKey(const Key('student-id-qr-close'));
    expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    expect(_card, findsOneWidget);
  });

  testWidgets('teacher or staff session on the student tab shows no card', (
    tester,
  ) async {
    for (final role in [CrmRole.teacher, CrmRole.staff]) {
      signIn(role, mssv: _id);
      await pumpStudentProfile(tester);
      expect(_card, findsNothing, reason: '$role');
      expect(find.byType(QrImageView), findsNothing, reason: '$role');
    }
  });

  testWidgets('teacher/staff profile tab has no student-ID QR', (tester) async {
    signIn(CrmRole.teacher);
    await tester.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        home: Scaffold(
          body: teacher.ProfileTab(
            name: 'Trần Thị Thử',
            code: 'Mã GV GVTEST01',
            onOpenInfo: null,
            onLogout: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(StudentIdQrCard), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('empty or missing MSSV shows no card and no QR', (tester) async {
    for (final mssv in <String?>[null, '', '   ']) {
      signIn(CrmRole.student, mssv: mssv);
      await pumpStudentProfile(tester);
      expect(_card, findsNothing, reason: '"$mssv"');
      expect(find.byType(QrImageView), findsNothing, reason: '"$mssv"');
    }
  });

  testWidgets('card and large view make no network call', (tester) async {
    signIn(CrmRole.student, mssv: _id);
    await pumpStudentProfile(tester);
    await tester.tap(_card);
    await tester.pumpAndSettle();
    expect(_dialog, findsOneWidget);
    await tester.tap(find.byKey(const Key('student-id-qr-close')));
    await tester.pumpAndSettle();
    expect(netCalls, 0);
  });

  testWidgets('card widget alone: non-student or blank ID renders nothing', (
    tester,
  ) async {
    Future<void> pumpCard(bool isStudent, String id) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentIdQrCard(
            name: _name,
            studentId: id,
            isStudent: isStudent,
          ),
        ),
      ),
    );
    await pumpCard(false, _id);
    expect(find.byType(QrImageView), findsNothing);
    for (final id in ['', '  ', '–']) {
      await pumpCard(true, id);
      expect(find.byType(QrImageView), findsNothing, reason: '"$id"');
    }
    await pumpCard(true, _id);
    expect(find.byType(QrImageView), findsOneWidget);
  });
}
