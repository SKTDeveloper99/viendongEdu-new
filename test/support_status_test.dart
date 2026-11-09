// Contract S4: request status strip in Hỏi nhà trường. Fixtures fictional.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/components/support_status_strip.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/models/support_status.dart';
import 'package:viendongedu2_flutter/screens/student_questions_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

void main() {
  group('SupportInfo.tryParse', () {
    test('missing, null or not an object = ordinary chat', () {
      expect(SupportInfo.tryParse(null), isNull);
      expect(SupportInfo.tryParse('in_progress'), isNull);
      expect(SupportInfo.tryParse([]), isNull);
    });

    test('maps every status; unknown reads as received', () {
      SupportStatus st(Object? s) =>
          SupportInfo.tryParse({'status': s})!.status;
      expect(st('submitted'), SupportStatus.submitted);
      expect(st('received'), SupportStatus.received);
      expect(st('in_progress'), SupportStatus.inProgress);
      expect(st('awaiting_confirmation'), SupportStatus.awaitingConfirmation);
      expect(st('resolved'), SupportStatus.resolved);
      expect(st('escalated'), SupportStatus.received);
      expect(st(null), SupportStatus.received);
    });

    test('owner and due date; due shown only while the school owes', () {
      final a = SupportInfo.tryParse({
        'status': 'in_progress',
        'owner_name': ' Cán Bộ Thử Nghiệm ',
        'due_at': '2026-11-12T03:00:00.000Z',
      })!;
      expect(a.ownerName, 'Cán Bộ Thử Nghiệm');
      expect(a.showsDue, isTrue);
      expect(supportDueText(a.dueAt!), '10:00 12/11/2026'); // Vietnam time
      final b = SupportInfo.tryParse({
        'status': 'resolved',
        'owner_name': '',
        'due_at': '2026-11-12T03:00:00.000Z',
      })!;
      expect(b.ownerName, isNull);
      expect(b.showsDue, isFalse);
      expect(
        SupportInfo.tryParse({'status': 'submitted', 'due_at': 'mai'})!.dueAt,
        isNull,
      );
    });

    test('confirmation lines are exactly what the CRM parses', () {
      final r = supportConfirmationReplies('AB12CD34-1');
      expect(r.satisfied, 'ĐÃ HÀI LÒNG AB12CD34-1');
      expect(r.unsatisfied, 'CHƯA GIẢI QUYẾT AB12CD34-1');
    });
  });

  testWidgets('strip marks steps done and the waiting step', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SupportStatusStrip(
            info: SupportInfo(status: SupportStatus.inProgress),
          ),
        ),
      ),
    );
    for (final label in [
      'Đã gửi',
      'Đã tiếp nhận',
      'Đang xử lý',
      'Bạn xác nhận',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byIcon(Icons.check), findsNWidgets(3));
    expect(find.text('Trạng thái: Đang xử lý'), findsOneWidget);
    expect(find.text('Đã hài lòng'), findsNothing);
  });

  group('Hỏi nhà trường screens', () {
    late List<String> posted;
    late Map<String, dynamic>? support;
    late Map<String, dynamic>? request;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppSession.instance
        ..emsToken = 'student-token'
        ..role = CrmRole.student
        ..mssv = '2600000001';
      posted = [];
      support = null;
      request = null;
      EmsApiService.client = MockClient((req) async {
        final p = req.url.path;
        if (req.method == 'POST' && p.endsWith('/messages')) {
          posted.add(jsonDecode(req.body)['body'] as String);
          return http.Response(
            jsonEncode({
              'message': {'id': 9},
            }),
            201,
            headers: _json,
          );
        }
        if (p.endsWith('/student/conversations')) {
          return http.Response(
            jsonEncode({
              'conversations': [
                {
                  'id': 7,
                  'subject': 'Yêu cầu thử nghiệm',
                  'status': 'open',
                  'last_message': {'body': 'Đã nhận'},
                  'support': support,
                },
                {'id': 8, 'subject': 'Câu hỏi thường', 'status': 'open'},
              ],
            }),
            200,
            headers: _json,
          );
        }
        if (p.endsWith('/student/conversations/7')) {
          return http.Response(
            jsonEncode({
              'conversation': {
                'id': 7,
                'subject': 'Yêu cầu thử nghiệm',
                'status': 'open',
              },
              'messages': [
                {'id': 1, 'body': 'Kết quả thử nghiệm', 'sender_type': 'staff'},
              ],
              'support': support,
              'support_request': request,
            }),
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
        ..mssv = null;
    });

    testWidgets('list: strip only on the support request', (t) async {
      support = {'status': 'received', 'owner_name': 'Cán Bộ Thử Nghiệm'};
      await t.pumpWidget(const MaterialApp(home: StudentQuestionsScreen()));
      await t.pumpAndSettle();
      expect(find.byType(SupportStatusStrip), findsOneWidget);
      expect(find.text('Đã tiếp nhận'), findsOneWidget);
    });

    testWidgets('ordinary chat: no strip anywhere', (t) async {
      await t.pumpWidget(const MaterialApp(home: StudentQuestionsScreen()));
      await t.pumpAndSettle();
      expect(find.byType(SupportStatusStrip), findsNothing);
      await t.tap(find.text('Yêu cầu thử nghiệm'));
      await t.pumpAndSettle();
      expect(find.text('Kết quả thử nghiệm'), findsOneWidget);
      expect(find.byType(SupportStatusStrip), findsNothing);
    });

    testWidgets('thread: owner and due date in Vietnam time', (t) async {
      support = {
        'status': 'in_progress',
        'owner_name': 'Cán Bộ Thử Nghiệm',
        'due_at': '2026-11-12T03:00:00.000Z',
      };
      await t.pumpWidget(const MaterialApp(home: StudentQuestionsScreen()));
      await t.pumpAndSettle();
      await t.tap(find.text('Yêu cầu thử nghiệm'));
      await t.pumpAndSettle();
      expect(find.text('Trạng thái: Đang xử lý'), findsOneWidget);
      expect(find.text('Người phụ trách: Cán Bộ Thử Nghiệm'), findsOneWidget);
      expect(
        find.text('Dự kiến phản hồi trước 10:00 12/11/2026'),
        findsOneWidget,
      );
    });

    testWidgets('awaiting confirmation sends the exact T-45 line', (t) async {
      support = {
        'status': 'awaiting_confirmation',
        'owner_name': 'Cán Bộ Thử Nghiệm',
      };
      request = {
        'state': 'awaiting_student',
        'confirmation_code': 'AB12CD34-1',
      };
      await t.pumpWidget(const MaterialApp(home: StudentQuestionsScreen()));
      await t.pumpAndSettle();
      await t.tap(find.text('Yêu cầu thử nghiệm'));
      await t.pumpAndSettle();
      expect(find.text('Trạng thái: Chờ bạn xác nhận'), findsOneWidget);
      expect(find.textContaining('Dự kiến phản hồi'), findsNothing);
      await t.tap(find.text('Đã hài lòng'));
      await t.pumpAndSettle();
      expect(posted, ['ĐÃ HÀI LÒNG AB12CD34-1']);
    });

    testWidgets('awaiting without a code: no buttons, reply guidance', (
      t,
    ) async {
      support = {'status': 'awaiting_confirmation'};
      await t.pumpWidget(const MaterialApp(home: StudentQuestionsScreen()));
      await t.pumpAndSettle();
      await t.tap(find.text('Yêu cầu thử nghiệm'));
      await t.pumpAndSettle();
      expect(find.text('Đã hài lòng'), findsNothing);
      expect(
        find.text('Hãy trả lời trong cuộc trao đổi bên dưới để xác nhận.'),
        findsOneWidget,
      );
    });
  });
}
