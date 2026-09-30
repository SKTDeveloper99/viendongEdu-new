import 'dart:async';

import 'package:viendongedu2_flutter/services/ems_api_service.dart';

/// Runs before every test file. Screens and services are tested on a phone
/// that HAS a connection; only test/network_layer_test.dart exercises the
/// "unsure network → never send a write" gate with the real probe.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  EmsApiService.probe = () async {};
  await testMain();
}
