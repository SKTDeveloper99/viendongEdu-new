import 'dart:async';

import 'package:flutter/material.dart';
import 'app_session.dart';
import 'ems_api_service.dart';

bool _handling = false;

/// Include silent badge, prefetch and outbox requests in session expiry.
void installCrmSessionGuard(GlobalKey<NavigatorState> key) {
  EmsApiService.onUnauthorized = (error) {
    final context = key.currentState?.overlay?.context;
    if (context != null) unawaited(handleCrmAuthError(context, error));
  };
}

/// Clear an expired session and navigate once, even for parallel failures.
/// A response from an earlier login must never sign out the current account.
Future<bool> handleCrmAuthError(BuildContext context, Object error) async {
  if (error is! EmsException || error.statusCode != 401) return false;
  final session = AppSession.instance;
  if (_handling || !session.hasEms || !context.mounted) return true;
  if (error.requestToken != null && error.requestToken != session.emsToken) {
    return true;
  }
  _handling = true;
  final navigator = Navigator.of(context, rootNavigator: true);
  try {
    // An expired token cannot revoke devices. Local sign-out must not wait
    // for Firebase/APNs or trigger another authenticated request.
    await session.clear(revokeDevice: false);
    if (navigator.mounted) {
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  } finally {
    _handling = false;
  }
  return true;
}
