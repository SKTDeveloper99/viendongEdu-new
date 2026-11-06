import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/components/schedule_exam_card.dart';
import 'package:viendongedu2_flutter/components/student_schedule_card.dart';
import 'package:viendongedu2_flutter/data/student_home_repository.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_view_model.dart';
import 'package:viendongedu2_flutter/features/student_home/widgets/today_schedule.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/models/crm_student_exams.dart';
import 'package:viendongedu2_flutter/screens/exam_screen.dart';
import 'package:viendongedu2_flutter/screens/schedule_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/crm_student_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

final today = DateTime(2026, 11, 5, 7);
Map<String, dynamic> exam(String id, int day) => {
  'exam_id': id,
  'exam_date': '2026-11-${day.toString().padLeft(2, '0')}T00:00:00.000Z',
  'subject_name': 'Môn thi $id',
  'start_time': '08:00',
  'duration_minutes': 90,
  'room': 'A101',
  'semester_code': '261',
};

void main() {
  late List<Map<String, dynamic>> exams;
  late bool classes;
  late bool examFailure;
  late bool classFailure;
  late bool offline;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..emsToken = 'fictional-exam-token'
      ..mssv = 'TEST-EXAM'
      ..role = CrmRole.student;
    exams = [exam('today', 5)];
    classes = false;
    examFailure = false;
    classFailure = false;
    offline = false;
    EmsApiService.client = MockClient((req) async {
      if (offline) throw http.ClientException('offline');
      final isExam = req.url.path.endsWith('/exams');
      final isSchedule = req.url.path.endsWith('/schedule');
      if ((isExam && examFailure) || (isSchedule && classFailure)) {
        // A non-retryable transport response keeps widget tests deterministic.
        return http.Response(
          '{"error":"Lỗi thử nghiệm"}',
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(
          isExam
              ? {'exams': exams}
              : isSchedule
              ? {
                  'schedule': [
                    if (classes)
                      {
                        'subject_name': 'Môn học',
                        'day_code': '5',
                        'start_time': '10:00',
                        'end_time': '11:00',
                      },
                  ],
                }
              : {'marks': []},
        ),
        200,
        headers: {'content-type': 'application/json', 'etag': '"exam-test"'},
      );
    });
  });

  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..mssv = null
      ..role = null;
  });

  Future<void> schedule(
    WidgetTester t, {
    double width = 390,
    bool dark = false,
  }) async {
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: dark ? VdTheme.dark() : VdTheme.light(),
        home: ScheduleScreen(now: () => today),
      ),
    );
    await t.pumpAndSettle();
  }

  for (final withClasses in [false, true]) {
    testWidgets('exam day ${withClasses ? 'with classes' : 'without class'}', (
      t,
    ) async {
      classes = withClasses;
      exams.add(exam('today', 5));
      await schedule(t);
      expect(find.byType(ScheduleExamCard), findsOneWidget);
      expect(find.text('Không có lịch học'), findsNothing);
      expect(
        find.byType(StudentScheduleCard),
        withClasses ? findsOneWidget : findsNothing,
      );
      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
      expect(find.textContaining('90 phút'), findsOneWidget);
      expect(find.text('Phòng: A101'), findsOneWidget);
      if (withClasses) {
        expect(
          t.getTopLeft(find.byType(ScheduleExamCard)).dy,
          lessThan(t.getTopLeft(find.byType(StudentScheduleCard)).dy),
        );
      }
    });
  }

  for (final bothFail in [false, true]) {
    testWidgets('exam failure with ${bothFail ? 'failed' : 'loaded'} classes', (
      t,
    ) async {
      examFailure = true;
      classFailure = bothFail;
      classes = true;
      await schedule(t);
      expect(find.text('Chưa kiểm tra được lịch thi'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Không có lịch học'), findsNothing);
      expect(
        find.byType(StudentScheduleCard),
        bothFail ? findsNothing : findsOneWidget,
      );
      examFailure = false;
      classFailure = false;
      await t.tap(find.text('Thử lại'));
      await t.pumpAndSettle();
      expect(find.byType(ScheduleExamCard), findsOneWidget);
      expect(find.text('Chưa kiểm tra được lịch thi'), findsNothing);
    });
  }

  testWidgets('empty requires successful exam and class loads', (t) async {
    exams = [];
    await schedule(t);
    expect(find.text('Không có lịch học'), findsOneWidget);
  });

  testWidgets('schedule uses a saved exam copy offline', (t) async {
    await CrmStudentApi.examsCached();
    await CrmStudentApi.scheduleViewCached();
    offline = true;
    await schedule(t);
    expect(find.byType(ScheduleExamCard), findsOneWidget);
    expect(
      find.textContaining('Chưa cập nhật được — dữ liệu lúc'),
      findsNWidgets(2),
    );
    expect(find.text('Không có lịch học'), findsNothing);
  });

  testWidgets('exam screen uses a saved copy and removes duplicate ids', (
    t,
  ) async {
    exams.add(exam('today', 5));
    await CrmStudentApi.examsCached();
    offline = true;
    await t.pumpWidget(const MaterialApp(home: ExamScreen()));
    await t.pumpAndSettle();
    expect(find.text('Môn thi today'), findsOneWidget);
    expect(
      find.textContaining('Chưa cập nhật được — dữ liệu lúc'),
      findsOneWidget,
    );
  });

  for (final dark in [false, true]) {
    testWidgets('exam card fits a narrow ${dark ? 'dark' : 'light'} phone', (
      t,
    ) async {
      exams[0]['subject_name'] =
          'Tên môn thi dài cần xuống dòng trên điện thoại nhỏ';
      exams[0]['room'] = 'Phòng thi dài cần xuống dòng trên điện thoại nhỏ';
      await schedule(t, width: 320, dark: dark);
      expect(find.byType(ScheduleExamCard), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  test('server calendar day survives timestamp offsets', () {
    final expectedOffset = Platform.environment['EXAM_TEST_UTC_OFFSET'];
    if (expectedOffset != null) {
      expect(
        DateTime(2026, 11, 5).timeZoneOffset.inHours,
        int.parse(expectedOffset),
      );
    }
    for (final zone in ['Z', '+07:00', '+11:00', '-05:00']) {
      final e = CrmStudentExam.fromJson({
        ...exam('zone', 5),
        'exam_date': '2026-11-05T00:00:00.000$zone',
      });
      expect(e.occursOn(DateTime(2026, 11, 5)), isTrue);
      expect(e.occursOn(DateTime(2026, 11, 4)), isFalse);
      expect(e.occursOn(DateTime(2026, 11, 6)), isFalse);
      expect(e.examDateFormatted, '05/11/2026');
    }
  });

  Future<StudentHomeViewModel> home(
    WidgetTester t, {
    bool expanded = true,
  }) async {
    final vm = StudentHomeViewModel(
      const StudentHomeRepository(),
      now: () => today,
      tickEvery: null,
    );
    await Future.wait([vm.loadTodaySchedule(), vm.loadExams()]);
    addTearDown(vm.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: vm,
              builder: (_, _) => TodaySchedule(
                vm: vm,
                scheduleExpanded: expanded,
                onToggleExpanded: () {},
              ),
            ),
          ),
        ),
        routes: {'/exam': (_) => const Scaffold(body: Text('Trang lịch thi'))},
      ),
    );
    await t.pumpAndSettle();
    return vm;
  }

  for (final expanded in [false, true]) {
    testWidgets('home shows today and next 7 days, expanded=$expanded', (
      t,
    ) async {
      exams = [
        exam('past', 4),
        exam('today', 5),
        exam('week', 12),
        exam('later', 13),
        exam('today', 5),
      ];
      final vm = await home(t, expanded: expanded);
      expect(vm.upcomingExams.map((e) => e.examId), ['today', 'week']);
      expect(find.byType(ScheduleExamCard), findsNWidgets(2));
      expect(find.text('Môn thi today'), findsOneWidget);
      expect(find.text('Môn thi week'), findsOneWidget);
      expect(find.text('Môn thi past'), findsNothing);
      expect(find.text('Môn thi later'), findsNothing);
      expect(find.textContaining('không có lịch học'), findsNothing);
      expect(vm.upNext.entry?.subject, 'Lịch thi · Môn thi today');
      await t.tap(find.text('Môn thi today'));
      await t.pumpAndSettle();
      expect(find.text('Trang lịch thi'), findsOneWidget);
    });
  }

  for (final bothFail in [false, true]) {
    testWidgets('home warns when exams fail, classes fail=$bothFail', (
      t,
    ) async {
      examFailure = true;
      classFailure = bothFail;
      final vm = await home(t);
      expect(vm.examsFailed, isTrue);
      expect(find.text('Chưa kiểm tra được lịch thi'), findsOneWidget);
      expect(find.textContaining('không có lịch học'), findsNothing);
      examFailure = false;
      await t.tap(find.text('Thử lại'));
      await t.pumpAndSettle();
      expect(vm.examsFailed, isFalse);
      expect(vm.hasExamToday, isTrue);
      expect(find.text('Chưa kiểm tra được lịch thi'), findsNothing);
      expect(find.byType(ScheduleExamCard), findsOneWidget);
    });
  }

  testWidgets('home labels saved exams offline', (t) async {
    await CrmStudentApi.examsCached();
    await CrmStudentApi.scheduleViewCached();
    offline = true;
    final vm = await home(t);
    expect(vm.examsStaleAt, isNotNull);
    expect(find.byType(ScheduleExamCard), findsOneWidget);
    expect(
      find.textContaining('Chưa cập nhật được — dữ liệu lúc'),
      findsNWidgets(2),
    );
  });
}
