import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/features/work/work_api.dart';
import 'package:viendongedu2_flutter/features/work_home/work_home_screen.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..userId = null
      ..isStaff = false
      ..canAssign = false
      ..trienKhai = false;
  });

  test('an old stored identity is topped up from /app/me', () {
    final s = AppSession.instance
      ..role = CrmRole.teacher
      ..userId = null
      ..isStaff = false
      ..canAssign = false
      ..trienKhai = false;
    final changed = s.applyAppMe({
      'user': {'id': 'u7'},
      'kinds': ['teacher', 'staff'],
      'permissions': {'canAssignTasks': true, 'trienKhai': true},
    });
    expect(changed, isTrue);
    expect(s.userId, 'u7');
    expect(s.isStaff, isTrue);
    expect(s.canAssign, isTrue);
    expect(s.trienKhai, isTrue);
    expect(
      s.applyAppMe({
        'user': {'id': 'u7'},
        'kinds': ['teacher', 'staff'],
        'permissions': {'canAssignTasks': true, 'trienKhai': true},
      }),
      isFalse,
    );
  });

  test('client_request_id is a v4 UUID, new each time', () {
    final a = newRequestId();
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(a),
      isTrue,
    );
    expect(newRequestId(), isNot(a));
  });

  testWidgets('the home reloads /app/me when the app comes back', (t) async {
    var me = 0;
    EmsApiService.client = MockClient((req) async {
      if (req.url.path.endsWith('/auth/app/me')) me++;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'counts': {},
            'can': {},
            'kinds': ['staff'],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    AppSession.instance
      ..emsToken = 'tok'
      ..role = CrmRole.staff
      ..userId = 'u1'
      ..isStaff = true;
    await t.pumpWidget(
      MaterialApp(theme: VdTheme.light(), home: const WorkHomeScreen()),
    );
    await t.pump(const Duration(milliseconds: 50));
    final before = me;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump(const Duration(milliseconds: 50));
    expect(me, greaterThan(before));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
