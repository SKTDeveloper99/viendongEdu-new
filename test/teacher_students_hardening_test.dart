import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/data/teacher_students_repository.dart';
import 'package:viendongedu2_flutter/features/teacher_students/class_students_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_students/student_detail_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_students/teacher_students_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_students/teacher_students_view_model.dart';
import 'package:viendongedu2_flutter/features/teacher_students/widgets/care_layout.dart';
import 'package:viendongedu2_flutter/features/teacher_students/widgets/money_card.dart';
import 'package:viendongedu2_flutter/models/teacher_care_student.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

import 'helpers/teacher_care_fixture.dart';

class WidgetCareRepository extends TeacherStudentsRepository {
  Future<TeacherCareStudent> Function()? read;
  @override
  Future<TeacherCareStudent> student(String mssv) => read!();
  @override
  Future<CachedCareStudents> students() async => (
    data: <TeacherCareStudent>[],
    savedAt: DateTime(2026, 10, 13),
    fresh: true,
  );
}

void oneVoice(WidgetTester tester) {
  final forbidden = RegExp(
    r'IMS|CRM|bảng kê|Kế toán|staff_reason|basis',
    caseSensitive: false,
  );
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    expect(forbidden.hasMatch(text.data ?? ''), isFalse);
  }
}

void main() {
  final savedAt = DateTime(2026, 10, 13, 10);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> detail(
    WidgetTester tester,
    TeacherCareStudent student,
    WidgetCareRepository repo, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        routes: {'/login': (_) => const Scaffold(body: Text('Test login'))},
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: StudentDetailScreen(
          student: student,
          sectionId: careSectionId,
          backLabel: 'Môn thử nghiệm',
          savedAt: savedAt,
          repository: repo,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    '0 students is a clear empty state; labelled back and refresh work',
    (tester) async {
      final vm = TeacherStudentsViewModel(WidgetCareRepository());
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(home: TeacherStudentsScreen(viewModel: vm)),
      );
      await tester.pumpAndSettle();
      expect(find.text('← Quay lại Trang chủ'), findsOneWidget);
      expect(find.textContaining('Chưa có sinh viên nào'), findsOneWidget);
      expect(find.text('Lớp của tôi'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'M-54 positive balance with owes false shows debt but no reminder',
    (tester) async {
      final s = careStudent();
      final repo = WidgetCareRepository()..read = () async => s;
      await detail(tester, s, repo);
      await tester.pumpAndSettle();
      expect(find.text('Còn nợ'), findsOneWidget);
      expect(find.text('1.500.000 đ'), findsOneWidget);
      expect(find.byType(OweBanner), findsNothing);
      expect(find.text('10:15 13/10'), findsOneWidget);
      oneVoice(tester);
    },
  );

  testWidgets('M-32 owes true alone shows the midterm reminder', (
    tester,
  ) async {
    final json = careStudentJson();
    json['dossier']['money_one'] = careMoneyJson(owes: true);
    final s = TeacherCareStudent.fromJson(json);
    await detail(tester, s, WidgetCareRepository()..read = () async => s);
    await tester.pumpAndSettle();
    expect(find.byType(OweBanner), findsOneWidget);
    expect(find.textContaining('02/11'), findsOneWidget);
    oneVoice(tester);
  });

  testWidgets(
    'unknown money and null attendance show exact unknown without figures',
    (tester) async {
      final json = careStudentJson();
      json['dossier']['money_one'] = {...careMoneyJson(), 'money_known': false};
      json['dossier']['sections'][0]['absent'] = null;
      final s = TeacherCareStudent.fromJson(json);
      await detail(tester, s, WidgetCareRepository()..read = () async => s);
      await tester.pumpAndSettle();
      expect(find.text('Đang đối chiếu'), findsNWidgets(2));
      expect(find.textContaining(RegExp(r'\d đ')), findsNothing);
      expect(find.text('Vắng'), findsNothing);
      expect(find.text('Cần chú ý'), findsNothing);
      oneVoice(tester);
    },
  );

  testWidgets('overpayment is stated in words, no raw payment-status wording', (
    tester,
  ) async {
    final json = careStudentJson();
    json['dossier']['money_one'] = {
      ...careMoneyJson(),
      'paid': 4500000,
      'balance': 0,
    };
    final s = TeacherCareStudent.fromJson(json);
    await detail(tester, s, WidgetCareRepository()..read = () async => s);
    await tester.pumpAndSettle();
    expect(find.text('Đã đóng dư'), findsOneWidget);
    expect(find.byType(OweBanner), findsNothing);
    oneVoice(tester);
  });

  testWidgets(
    'slow detail: visible progress, last copy, then labelled failure and retry',
    (tester) async {
      final pending = Completer<TeacherCareStudent>();
      final repo = WidgetCareRepository()..read = () => pending.future;
      await detail(tester, careStudent(), repo);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('1.500.000 đ'), findsOneWidget);
      pending.completeError(EmsException('IMS CRM Kế toán staff_reason'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      expect(
        find.textContaining('Chưa cập nhật được — dữ liệu lúc'),
        findsOneWidget,
      );
      final stale = tester.widget<Text>(find.textContaining('dữ liệu lúc'));
      expect(stale.style!.fontSize, 16);
      oneVoice(tester);
      repo.read = () async => careStudent();
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsNothing);
      expect(find.textContaining('dữ liệu lúc'), findsNothing);
    },
  );

  for (final status in [401, 403, 404]) {
    testWidgets('detail $status never leaves student figures visible', (
      tester,
    ) async {
      final repo = WidgetCareRepository()
        ..read = () async => throw EmsException(
          'IMS CRM Kế toán staff_reason',
          statusCode: status,
        );
      await detail(tester, careStudent(), repo);
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp(r'\d đ')), findsNothing);
      expect(find.text('Sinh viên thử nghiệm 0'), findsNothing);
      if (status == 401) {
        expect(find.text('Test login'), findsOneWidget);
      } else {
        expect(find.text('Thử lại'), findsOneWidget);
      }
      oneVoice(tester);
    });
  }

  testWidgets(
    'large text on a narrow phone: labels wrap and back button stays usable',
    (tester) async {
      final json = careStudentJson();
      json['dossier']['full_name'] =
          'Sinh viên thử nghiệm có tên hiển thị rất dài';
      final s = TeacherCareStudent.fromJson(json);
      await detail(
        tester,
        s,
        WidgetCareRepository()..read = () async => s,
        scale: 2,
      );
      await tester.pumpAndSettle();
      final back = find.widgetWithText(
        OutlinedButton,
        '← Quay lại Môn thử nghiệm',
      );
      expect(back, findsOneWidget);
      expect(tester.getSize(back).height, greaterThanOrEqualTo(56));
      await tester.scrollUntilVisible(find.text('Học phí'), 350);
      expect(tester.takeException(), isNull);
      oneVoice(tester);
    },
  );

  testWidgets(
    '1001 students: lazy list reaches the last student and labelled back navigates',
    (tester) async {
      final c = CareClass(
        sectionId: careSectionId,
        title: 'Môn thử nghiệm',
        students: List.generate(1001, careStudent),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ClassStudentsScreen(careClass: c, savedAt: savedAt),
                  ),
                ),
                child: const Text('Test open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Test open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1001 sinh viên'), findsOneWidget);
      expect(
        tester.widgetList<CareRow>(find.byType(CareRow)).length,
        lessThan(20),
      );
      await tester.scrollUntilVisible(
        find.text('Sinh viên thử nghiệm 1000'),
        1500,
        maxScrolls: 150,
      );
      expect(find.text('Sinh viên thử nghiệm 1000'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, 150000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('← Quay lại Sinh viên của tôi'));
      await tester.pumpAndSettle();
      expect(find.text('Test open'), findsOneWidget);
    },
  );
}
