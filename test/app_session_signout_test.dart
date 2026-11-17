import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    AppSession.revokeDeviceOverride = null;
    AppSession.deviceRevokeLimit = const Duration(seconds: 3);
  });

  test(
    'sign-out does not wait on a push-token revoke that never ends',
    () async {
      final asked = <String>[];
      AppSession.revokeDeviceOverride = (id) {
        asked.add(id);
        return Completer<void>().future; // a phone with no push token
      };
      AppSession.deviceRevokeLimit = const Duration(milliseconds: 50);
      AppSession.instance
        ..emsToken = 'tok'
        ..role = CrmRole.staff
        ..userId = '42';
      final sw = Stopwatch()..start();
      await AppSession.instance.clear();
      expect(asked, ['st_42']);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      expect(AppSession.instance.emsToken, isNull);
      expect(AppSession.instance.isLoggedIn, isFalse);
    },
  );
}
