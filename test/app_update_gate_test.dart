import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/services/app_update_gate.dart';

void main() {
  test('a build below the server minimum is outdated', () {
    expect(AppUpdateGate.isOutdated('1.1.44+86', '6.0.4'), isTrue);
    expect(AppUpdateGate.isOutdated('6.0.3+3', '6.0.4'), isTrue);
    expect(AppUpdateGate.isOutdated('6.0.4+4', '6.0.4'), isFalse);
    expect(AppUpdateGate.isOutdated('6.0.5', '6.0.4'), isFalse);
    expect(AppUpdateGate.isOutdated('6.1.0', '6.0.4'), isFalse);
  });

  test('garbage never locks a user out', () {
    expect(AppUpdateGate.isOutdated('', '6.0.4'), isFalse);
    expect(AppUpdateGate.isOutdated('6.0.4', ''), isFalse);
    expect(AppUpdateGate.isOutdated('x.y', '6.0.4'), isFalse);
  });
}
