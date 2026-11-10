import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../services/app_session.dart';

/// Keeps the in-app CRM web view's storage tied to one app login (T1).
/// The view's cookies, local storage and cache are wiped:
/// - when the teacher logs out of the app (AppSession clear hook);
/// - before a page opens for a different app token than last time,
///   including the first opening after the app starts (the WebView store
///   outlives the process, the app's memory does not).
class CrmWebSession {
  CrmWebSession({String? Function()? token})
    : _token = token ?? (() => AppSession.instance.emsToken);

  static final CrmWebSession instance = CrmWebSession();

  final String? Function() _token;
  Future<void> Function()? _wipe;
  String? _openedFor;
  bool _hooked = false;

  /// Installed by the web view layer (cookie manager + storage clear).
  void attach(Future<void> Function() wipe) {
    _wipe = wipe;
    if (!_hooked) {
      _hooked = true;
      AppSession.clearHooks.add(_onLogout);
    }
  }

  void _onLogout() {
    _openedFor = null;
    final wipe = _wipe;
    if (wipe != null) unawaited(wipe().catchError((Object _) {}));
  }

  static String? _fingerprint(String? token) => token == null || token.isEmpty
      ? null
      : sha256.convert(utf8.encode(token)).toString();

  /// Call before every opening. Wipes when the app token is not the one the
  /// stored web state belongs to (never compares raw tokens).
  Future<void> beforeOpen() async {
    final fp = _fingerprint(_token());
    if (fp != null && fp == _openedFor) return;
    final wipe = _wipe;
    if (wipe != null) await wipe();
    _openedFor = fp;
  }
}
