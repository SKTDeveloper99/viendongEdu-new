// T2 / LAW T-28: teaching report after attendance. Fixtures fictional.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/data/teaching_report_repository.dart';
import 'package:viendongedu2_flutter/features/teaching_report/teaching_report_flow.dart';
import 'package:viendongedu2_flutter/features/teaching_report/widgets/pending_reports_card.dart';
import 'package:viendongedu2_flutter/features/teaching_report/widgets/teaching_report_sheet.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/models/teaching_report_models.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _row({int? periods, String start = '07:30:00'}) => {
  'id': 41,
  'meeting_date': '2026-11-10',
  'start_time': start,
  'end_time': '09:45',
  'room': 'P.101',
  'section_code': 'TN-LOP-1',
  'subject_name': 'Môn thử nghiệm',
  'outcome': 'unknown',
  'scheduled_periods': ?periods,
};

const _session = EmsSession(
  sectionId: 'sec-1',
  sectionCode: 'TN-LOP-1',
  sessionDate: '2026-11-10',
  sessionKey: '1:07-30:2026-11-10',
  subjectName: 'Môn thử nghiệm',
  startTime: '07:30',
  endTime: '09:45',
);

QueuedTeachingReport _queued(TeachingReportChoice c) => QueuedTeachingReport(
  sectionCode: 'TN-LOP-1',
  meetingDate: '2026-11-10',
  startTime: '07:30',
  subjectName: 'Môn thử nghiệm',
  choice: c,
  createdAt: DateTime(2026, 11, 10, 10),
);

const _held3 = TeachingReportChoice(outcome: TeachingOutcome.held, periods: 3);

void main() {
  late List<Map<String, dynamic>> posts;
  late List<Map<String, dynamic>> pending;
  late int postStatus;
  late bool offline;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..emsToken = 'test-teacher-token'
      ..role = CrmRole.teacher
      ..teacherId = 'T-TEST-1';
    posts = [];
    pending = [_row(periods: 3)];
    postStatus = 200;
    offline = false;
    EmsApiService.client = MockClient((req) async {
      if (offline) throw http.ClientException('test-offline');
      if (req.method == 'POST') {
        posts.add({
          'path': req.url.path,
          ...jsonDecode(req.body) as Map<String, dynamic>,
        });
        return http.Response(
          jsonEncode(
            postStatus == 200 ? {'ok': true} : {'error': 'Lỗi thử nghiệm.'},
          ),
          postStatus,
          headers: _json,
        );
      }
      return http.Response(
        jsonEncode({'semester': '261', 'pending': pending}),
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

  group('model', () {
    test('T-28 choices: held 1–15, cancelled 0', () {
      expect(_held3.valid, isTrue);
      expect(
        const TeachingReportChoice(
          outcome: TeachingOutcome.held,
          periods: 0,
        ).valid,
        isFalse,
      );
      expect(
        const TeachingReportChoice(
          outcome: TeachingOutcome.held,
          periods: 16,
        ).valid,
        isFalse,
      );
      expect(
        const TeachingReportChoice(
          outcome: TeachingOutcome.cancelled,
          periods: 0,
        ).valid,
        isTrue,
      );
    });

    test('pending row: key, HH:mm, scheduled periods only 1–15', () {
      final s = TeachingReportSession.fromJson(_row(periods: 3));
      expect(s.key, 'TN-LOP-1|2026-11-10|07:30');
      expect(s.endTime, '09:45');
      expect(s.scheduledPeriods, 3);
      expect(
        TeachingReportSession.fromJson(_row(periods: 0)).scheduledPeriods,
        isNull,
      );
      expect(TeachingReportSession.fromJson(_row()).scheduledPeriods, isNull);
    });

    test('queued report survives a round trip; bad rows are dropped', () {
      final q = _queued(_held3).withProblem('x');
      final back = QueuedTeachingReport.tryParse(q.toJson())!;
      expect(back.key, q.key);
      expect(back.choice.periods, 3);
      expect(back.problem, 'x');
      expect(
        QueuedTeachingReport.tryParse({...q.toJson(), 'periods': 0}),
        isNull,
      );
      expect(QueuedTeachingReport.tryParse('rác'), isNull);
    });
  });

  group('repository', () {
    const repo = TeachingReportRepository();

    test('sends to the matching session with the tapped periods', () async {
      expect(await repo.report(_queued(_held3)), TeachingReportResult.sent);
      expect(posts.single['path'], '/api/teaching-reports/41');
      expect(posts.single['outcome'], 'held');
      expect(posts.single['actual_periods'], 3);
      expect(await repo.queued(), isEmpty);
    });

    test('409 counts as already reported', () async {
      postStatus = 409;
      expect(
        await repo.report(_queued(_held3)),
        TeachingReportResult.alreadyReported,
      );
      expect(await repo.queued(), isEmpty);
    });

    test('offline: kept as CHƯA GỬI, drained later', () async {
      offline = true;
      expect(await repo.report(_queued(_held3)), TeachingReportResult.queued);
      expect((await repo.queued()).single.problem, isNull);
      offline = false;
      expect(await repo.drain(), 1);
      expect(posts.single['actual_periods'], 3);
      expect(await repo.queued(), isEmpty);
    });

    test('a refusal is said, never queued', () async {
      postStatus = 400;
      await expectLater(
        repo.report(_queued(_held3)),
        throwsA(isA<EmsException>()),
      );
      expect(await repo.queued(), isEmpty);
    });

    test('no matching session on the server: queued with a reason', () async {
      pending = [];
      expect(await repo.report(_queued(_held3)), TeachingReportResult.queued);
      expect((await repo.queued()).single.problem, contains('Máy chủ chưa có'));
      expect(posts, isEmpty);
    });
  });

  group('sheet', () {
    Future<TeachingReportChoice?> open(WidgetTester t, int? n) async {
      TeachingReportChoice? got;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => got = await showTeachingReportSheet(
                context,
                title: 'Môn thử nghiệm',
                when: '10/11/2026 · 07:30 – 09:45',
                scheduledPeriods: n,
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      return got;
    }

    testWidgets('known timetable: one tap reports the full periods', (t) async {
      TeachingReportChoice? got;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => got = await showTeachingReportSheet(
                context,
                title: 'Môn thử nghiệm',
                when: '10/11/2026',
                scheduledPeriods: 3,
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      expect(find.text('Báo cáo giảng dạy buổi này'), findsOneWidget);
      expect(find.text('Theo thời khóa biểu: 3 tiết.'), findsOneWidget);
      await t.tap(find.text('Đã dạy đủ 3 tiết'));
      await t.pumpAndSettle();
      expect(got!.outcome, TeachingOutcome.held);
      expect(got!.periods, 3);
    });

    testWidgets('fewer periods: stepper starts below the timetable', (t) async {
      await open(t, 3);
      expect(find.text('2 tiết'), findsOneWidget);
      expect(find.text('Gửi: đã dạy 2 tiết'), findsOneWidget);
    });

    testWidgets('unknown timetable: no one-tap number, must choose', (t) async {
      await open(t, null);
      expect(find.textContaining('Đã dạy đủ'), findsNothing);
      expect(find.text('— tiết'), findsOneWidget);
      final send = t.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Chọn số tiết'),
      );
      expect(send.onPressed, isNull);
      await t.tap(find.byTooltip('Thêm một tiết'));
      await t.pump();
      expect(find.text('Gửi: đã dạy 1 tiết'), findsOneWidget);
    });
  });

  group('after saving attendance', () {
    Future<void> offer(WidgetTester t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => offerTeachingReport(context, _session),
                child: const Text('lưu xong'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('lưu xong'));
      await t.pumpAndSettle();
    }

    testWidgets('asks, sends and says so', (t) async {
      await offer(t);
      await t.tap(find.text('Đã dạy đủ 3 tiết'));
      await t.pumpAndSettle();
      expect(posts.single['actual_periods'], 3);
      expect(
        find.text('Đã gửi báo cáo giảng dạy: Đã dạy 3 tiết.'),
        findsOneWidget,
      );
    });

    testWidgets('Buổi học nghỉ records 0', (t) async {
      await offer(t);
      await t.tap(find.text('Buổi học nghỉ'));
      await t.pumpAndSettle();
      expect(posts.single['outcome'], 'cancelled');
      expect(posts.single['actual_periods'], 0);
    });

    testWidgets('already reported on the server: not asked', (t) async {
      pending = [];
      await offer(t);
      expect(find.text('Báo cáo giảng dạy buổi này'), findsNothing);
    });

    testWidgets('offline: asked anyway, kept as CHƯA GỬI', (t) async {
      offline = true;
      await offer(t);
      expect(find.textContaining('Đã dạy đủ'), findsNothing); // N unknown
      await t.tap(find.byTooltip('Thêm một tiết'));
      await t.tap(find.byTooltip('Thêm một tiết'));
      await t.pump();
      await t.tap(find.text('Gửi: đã dạy 2 tiết'));
      await t.pumpAndSettle();
      expect(find.textContaining('CHƯA GỬI báo cáo'), findsOneWidget);
      expect(
        (await const TeachingReportRepository().queued()).single.choice.periods,
        2,
      );
    });
  });

  testWidgets('Ngày làm việc: pending sessions and CHƯA GỬI reports', (
    t,
  ) async {
    pending = [
      _row(periods: 3),
      {..._row(start: '13:00'), 'id': 42, 'subject_name': 'Môn chiều'},
    ];
    offline = true;
    await const TeachingReportRepository().report(_queued(_held3));
    offline = false;
    postStatus = 503; // drain cannot send yet
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PendingTeachingReports()),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Buổi chưa báo cáo giảng dạy'), findsOneWidget);
    expect(find.text('Môn chiều'), findsOneWidget);
    expect(find.textContaining('CHƯA GỬI — Đã dạy 3 tiết'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // one open + one queued
  });
}
