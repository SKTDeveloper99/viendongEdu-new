/// Navigation rules inside the CRM web view (T1):
/// - only `https://<our CRM host>` loads inside the view;
/// - the pass failure page and the web login form are never shown: the app
///   replaces them with its own Vietnamese retry line;
/// - every other link opens in the system browser.
library;

import 'package:flutter/foundation.dart' show kDebugMode;

/// Debug builds only: the test copy on a tunnel (`http://localhost:3100`).
bool crmDebugLoopback(Uri uri) =>
    kDebugMode &&
    uri.scheme.toLowerCase() == 'http' &&
    (uri.host == 'localhost' || uri.host == '127.0.0.1');

enum CrmNav { allow, passFailed, external, block }

CrmNav crmNavigation(Uri uri, {required String host}) {
  final scheme = uri.scheme.toLowerCase();
  // Blank frames and same-page blob previews only; data: URLs could carry
  // script from anywhere, so they never load (JavaScript is for our host).
  if (scheme == 'about' || scheme == 'blob') return CrmNav.allow;
  if ((scheme == 'https' || crmDebugLoopback(uri)) &&
      uri.host.toLowerCase() == host.toLowerCase()) {
    final path = uri.path.toLowerCase();
    if (path.startsWith('/pass-failed') ||
        path == '/login' ||
        path.startsWith('/login.')) {
      return CrmNav.passFailed;
    }
    return CrmNav.allow;
  }
  if (scheme == 'https' ||
      scheme == 'http' ||
      scheme == 'mailto' ||
      scheme == 'tel') {
    return CrmNav.external;
  }
  return CrmNav.block; // intent:, javascript:, file:, custom schemes
}
