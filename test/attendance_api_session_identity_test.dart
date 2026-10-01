import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/data/api/attendance_api.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  const key = '44660:2445a34b-af8a-4841-af66-56465e67d05f:2026-10-05';
  const scheduleId = '2445a34b-af8a-4841-af66-56465e67d05f';
  late Uri? rosterRequest;

  setUp(() {
    rosterRequest = null;
    AppSession.instance.emsToken = 'test-token';
    EmsApiService.client = MockClient((request) async {
      rosterRequest = request.url;
      return http.Response(
        jsonEncode({'session_key': key, 'students': <Object>[]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
  });

  test(
    'scheduled session ID is carried into the roster key computation',
    () async {
      final session = EmsSession.fromJson({
        'schedule_session_id': scheduleId,
        'section_id': '65933960-4db4-40c2-b2e5-c3cef4371c86',
        'section_code': 'GEP34_261_GRA23721_17DHC_KTNA_HOCLAI',
        'subject_name': 'Kỹ thuật nhiếp ảnh',
        'session_date': '2026-10-05',
        'start_time': '13:00',
        'end_time': '16:15',
        'roster_size': 2,
        'session_key': key,
      });

      final roster = await AttendanceApi.roster(session);

      expect(rosterRequest?.queryParameters['session_id'], scheduleId);
      expect(rosterRequest?.queryParameters['start_time'], '13:00');
      expect(roster.sessionKey, key);
      expect(
        EmsSession.fromJson(session.toJson()).scheduleSessionId,
        scheduleId,
      );
    },
  );
}
