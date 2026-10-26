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

  test('same name, lower build is outdated when the server names a build', () {
    // 2026-10-26: 101 (tdat535) and 102 were both 6.0.8.
    expect(AppUpdateGate.isBuildOutdated('101', 103), isTrue);
    expect(AppUpdateGate.isBuildOutdated('101', '103'), isTrue);
    expect(AppUpdateGate.isBuildOutdated('103', 103), isFalse);
    expect(AppUpdateGate.isBuildOutdated('104', 103), isFalse);
  });

  test('a missing or odd build minimum never locks a user out', () {
    expect(AppUpdateGate.isBuildOutdated('101', null), isFalse);
    expect(AppUpdateGate.isBuildOutdated('101', ''), isFalse);
    expect(AppUpdateGate.isBuildOutdated('', 103), isFalse);
    expect(AppUpdateGate.isBuildOutdated('abc', 103), isFalse);
  });
}
