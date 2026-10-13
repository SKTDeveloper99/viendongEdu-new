import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/crm_teacher_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/offline_snapshot.dart';

import 'helpers/teacher_care_fixture.dart';

http.Response response(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status, headers: careJsonHeaders);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..emsToken = 'test-token'
      ..role = CrmRole.teacher
      ..teacherId = 'teacher-test';
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..teacherId = null;
  });

  void pages(
    int total, {
    int limit = 100,
    Map<String, dynamic> Function(Map<String, dynamic> body, int page)? alter,
    List<int>? hits,
  }) {
    EmsApiService.client = MockClient((req) async {
      expect(req.method, 'GET');
      expect(req.url.path, '/api/student-care');
      expect(req.url.queryParameters['limit'], '100');
      final page = int.parse(req.url.queryParameters['page']!);
      hits?.add(page);
      final start = (page - 1) * limit;
      final count = (total - start).clamp(0, limit);
      final body = <String, dynamic>{
        'page': page,
        'limit': limit,
        'total': total,
        'students': List.generate(count, (i) => careStudentJson(start + i)),
      };
      return response(alter?.call(body, page) ?? body);
    });
  }

  for (final total in [0, 1, 100, 1001, 2101]) {
    test(
      '$total students: every page once, no missing or duplicate student',
      () async {
        final hits = <int>[];
        pages(total, hits: hits);
        final r = await CrmTeacherApi.studentCare();
        expect(r.fresh, isTrue);
        expect(
          r.data.map((s) => s.mssv).toList(),
          List.generate(total, (i) => 'TEST25-$i'),
        );
        expect(
          hits,
          List.generate(total == 0 ? 1 : (total / 100).ceil(), (i) => i + 1),
        );
        EmsApiService.client = MockClient(
          (_) async => throw StateError('offline'),
        );
        final old = await CrmTeacherApi.studentCare();
        expect(old.fresh, isFalse);
        expect(old.data, hasLength(total));
        expect(old.data.map((s) => s.mssv), r.data.map((s) => s.mssv));
      },
    );
  }

  test('uses the server page size, including numeric strings', () async {
    final hits = <int>[];
    pages(
      101,
      limit: 50,
      hits: hits,
      alter: (body, _) => {...body, 'total': '${body['total']}', 'limit': '50'},
    );
    expect((await CrmTeacherApi.studentCare()).data, hasLength(101));
    expect(hits, [1, 2, 3]);
  });

  final corruptions =
      <String, Map<String, dynamic> Function(Map<String, dynamic>, int)>{
        'short page': (b, _) => {
          ...b,
          'students': (b['students'] as List).take(2).toList(),
        },
        'missing list': (b, _) => {...b, 'students': null},
        'invalid row': (b, _) => {
          ...b,
          'students': [null, ...(b['students'] as List).skip(1)],
        },
        'missing ID': (b, _) => {
          ...b,
          'students': [
            {...careStudentJson(), 'mssv': ''},
            ...(b['students'] as List).skip(1),
          ],
        },
        'duplicate page': (b, p) => p == 1
            ? b
            : {...b, 'students': List.generate(100, careStudentJson)},
        'changing total': (b, p) => {...b, 'total': p == 1 ? 200 : 201},
        'wrong page': (b, _) => {...b, 'page': 1},
        'changing limit': (b, p) => {...b, 'limit': p == 1 ? 100 : 50},
        'missing total': (b, _) => {...b, 'total': null},
      };
  for (final entry in corruptions.entries) {
    test(
      '${entry.key}: rejects incomplete data and preserves the complete cache',
      () async {
        pages(3);
        final good = await CrmTeacherApi.studentCare();
        pages(200, alter: entry.value);
        final r = await CrmTeacherApi.studentCare();
        expect(r.fresh, isFalse);
        expect(r.data.map((s) => s.mssv), good.data.map((s) => s.mssv));
        pages(200, alter: entry.value);
        await OfflineSnapshot.clearCurrentAccount();
        await expectLater(
          CrmTeacherApi.studentCare(),
          throwsA(isA<EmsException>()),
        );
      },
    );
  }

  test('failure on a later page keeps the whole previous list', () async {
    pages(101);
    await CrmTeacherApi.studentCare();
    EmsApiService.client = MockClient((req) async {
      if (req.url.queryParameters['page'] == '2') throw StateError('offline');
      return response({
        'page': 1,
        'limit': 100,
        'total': 200,
        'students': List.generate(100, careStudentJson),
      });
    });
    final r = await CrmTeacherApi.studentCare();
    expect(r.fresh, isFalse);
    expect(r.data, hasLength(101));
  });

  testWidgets(
    'slow network times out to the complete cache without another GET',
    (tester) async {
      pages(1);
      await CrmTeacherApi.studentCare();
      final pending = Completer<http.Response>();
      var calls = 0;
      EmsApiService.client = MockClient((_) {
        calls++;
        return pending.future;
      });
      final read = CrmTeacherApi.studentCare();
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));
      final r = await read;
      expect(r.fresh, isFalse);
      expect(r.data, hasLength(1));
      expect(calls, 1);
      pending.complete(response({}));
      await tester.pump();
    },
  );

  for (final status in [401, 403]) {
    test('$status on page two propagates despite the cache', () async {
      pages(1);
      await CrmTeacherApi.studentCare();
      EmsApiService.client = MockClient(
        (req) async => req.url.queryParameters['page'] == '2'
            ? response({'error': 'CRM staff_reason'}, status)
            : response({
                'page': 1,
                'limit': 100,
                'total': 101,
                'students': List.generate(100, careStudentJson),
              }),
      );
      await expectLater(
        CrmTeacherApi.studentCare(),
        throwsA(
          isA<EmsException>().having((e) => e.statusCode, 'status', status),
        ),
      );
      expect(await OfflineSnapshot.load('teacher_student_care'), isNull);
    });
  }

  for (final status in [401, 403]) {
    test('detail $status invalidates the list copy too', () async {
      pages(1);
      await CrmTeacherApi.studentCare();
      EmsApiService.client = MockClient(
        (_) async => response({'error': 'denied'}, status),
      );
      await expectLater(
        CrmTeacherApi.studentCareOne('TEST25-0'),
        throwsA(isA<EmsException>()),
      );
      expect(await OfflineSnapshot.load('teacher_student_care'), isNull);
    });
  }

  test('cache is isolated by teacher and cleared on sign-out', () async {
    pages(1);
    await CrmTeacherApi.studentCare();
    AppSession.instance.teacherId = 'another-teacher-test';
    EmsApiService.client = MockClient((_) async => throw StateError('offline'));
    await expectLater(
      CrmTeacherApi.studentCare(),
      throwsA(isA<EmsException>()),
    );
    AppSession.instance.teacherId = 'teacher-test';
    expect((await CrmTeacherApi.studentCare()).data, hasLength(1));
    await OfflineSnapshot.clearCurrentAccount();
    await expectLater(
      CrmTeacherApi.studentCare(),
      throwsA(isA<EmsException>()),
    );
  });

  test(
    'legacy partial caches and incomplete envelopes are never presented as complete',
    () async {
      EmsApiService.client = MockClient(
        (_) async => throw StateError('offline'),
      );
      for (final data in [
        [careStudentJson()],
        {
          'complete': false,
          'total': 1,
          'students': [careStudentJson()],
        },
        {
          'complete': true,
          'total': 2,
          'students': [careStudentJson()],
        },
      ]) {
        await OfflineSnapshot.save('teacher_student_care', data);
        await expectLater(
          CrmTeacherApi.studentCare(),
          throwsA(isA<EmsException>()),
        );
      }
    },
  );

  test(
    'account change during a request does not save into the new account',
    () async {
      EmsApiService.client = MockClient((_) async {
        AppSession.instance
          ..emsToken = 'another-token'
          ..teacherId = 'another-teacher-test';
        return response({
          'page': 1,
          'limit': 100,
          'total': 1,
          'students': [careStudentJson()],
        });
      });
      await expectLater(
        CrmTeacherApi.studentCare(),
        throwsA(isA<EmsException>()),
      );
      expect(await OfflineSnapshot.load('teacher_student_care'), isNull);
    },
  );

  test(
    'single student validates identity and strips staff fields in the cache',
    () async {
      EmsApiService.client = MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, '/api/student-care/student/TEST25-0');
        return response({'available': true, 'student': careStudentJson()});
      });
      final s = await CrmTeacherApi.studentCareOne('TEST25-0');
      expect(s.money.balance, 1500000);
      final json = jsonEncode(s.toJson());
      expect(
        RegExp('basis|staff_reason|ims_balance|payment_status').hasMatch(json),
        isFalse,
      );
      EmsApiService.client = MockClient(
        (_) async =>
            response({'available': true, 'student': careStudentJson()}),
      );
      await expectLater(
        CrmTeacherApi.studentCareOne('TEST25-1'),
        throwsA(isA<EmsException>()),
      );
    },
  );
}
