import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/crm_student_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

const _section = {
  'section_code': 'TEST-SECTION-B',
  'semester_code': '261',
  'subject_code': 'TEST-B',
  'subject_name': 'Môn thử nghiệm chưa xếp lịch',
};
const _body = {
  'schedule': [
    {'section_code': 'TEST-SECTION-A', 'day_code': '4'},
  ],
  'chua_co_lich': [_section],
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..emsToken = 'test-token'
      ..role = CrmRole.student
      ..mssv = 'TEST-STUDENT';
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..mssv = null;
  });

  test('S-38 parses all four fields separately from recurring slots', () {
    final view = CrmStudentScheduleView.fromJson(_body);
    expect(view.schedule, hasLength(1));
    expect(view.schedule.single.sectionCode, 'TEST-SECTION-A');
    expect(view.chuaCoLich, hasLength(1));
    final section = view.chuaCoLich.single;
    expect(section.sectionCode, _section['section_code']);
    expect(section.semesterCode, _section['semester_code']);
    expect(section.subjectCode, _section['subject_code']);
    expect(section.subjectName, _section['subject_name']);
  });

  test('older servers: missing, null and empty field produce no subjects', () {
    for (final body in <Map<String, dynamic>>[
      {},
      {'chua_co_lich': null},
      {'chua_co_lich': <Object>[]},
    ]) {
      expect(CrmStudentScheduleView.fromJson(body).chuaCoLich, isEmpty);
    }
  });

  test(
    'cached view preserves subjects through 304 and offline fallback',
    () async {
      var calls = 0;
      EmsApiService.client = MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, '/api/student/me/schedule');
        expect(req.url.queryParameters, {'semester': '261'});
        calls++;
        if (calls == 1) {
          return http.Response(
            jsonEncode(_body),
            200,
            headers: {
              'content-type': 'application/json',
              'etag': '"schedule-test"',
            },
          );
        }
        expect(req.headers['If-None-Match'], '"schedule-test"');
        if (calls == 2) return http.Response('', 304);
        throw http.ClientException('offline');
      });
      final first = await CrmStudentApi.scheduleViewCached(semester: '261');
      expect(first.fresh, isTrue);
      expect(first.data.chuaCoLich.single.subjectCode, 'TEST-B');
      final validated = await CrmStudentApi.scheduleViewCached(semester: '261');
      expect(validated.fresh, isTrue);
      CrmStudentScheduleView? stored;
      final offline = await CrmStudentApi.scheduleViewCached(
        semester: '261',
        onStored: (view, _) => stored = view,
      );
      expect(stored!.chuaCoLich.single.subjectCode, 'TEST-B');
      expect(offline.fresh, isFalse);
      expect(offline.data.chuaCoLich.single.subjectCode, 'TEST-B');
      expect(offline.data.schedule.single.sectionCode, 'TEST-SECTION-A');
      expect(calls, 3);
    },
  );

  test('home APIs still return only timetable slots', () async {
    EmsApiService.client = MockClient(
      (_) async => http.Response(
        jsonEncode(_body),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final direct = await CrmStudentApi.schedule();
    final cached = await CrmStudentApi.scheduleCached();
    expect(direct.map((s) => s.sectionCode), ['TEST-SECTION-A']);
    expect(cached.data.map((s) => s.sectionCode), ['TEST-SECTION-A']);
  });
}
