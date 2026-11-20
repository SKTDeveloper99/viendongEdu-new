import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/crm_web/crm_web_target.dart';
import '../../services/app_session.dart';
import 'android_photo_picker.dart';
import 'crm_page_screen.dart';
import 'crm_web_session.dart';
import 'crm_webview_surface.dart';

bool _attached = false;

/// App routes `/crm/tasks…` and `/crm/nhom…` (tiles and task pushes):
/// teachers only, allow-listed pages only; anything else is not a route.
Route<void>? crmPageRoute(RouteSettings settings) {
  final named = CrmTarget.fromRouteName(settings.name ?? '');
  // The home may pass the page's own title (server-led home, proposed P-50).
  final arg = settings.arguments;
  final target = named?.withLabel(arg is String ? arg : null);
  final s = AppSession.instance;
  if (target == null || !(s.isGiangVien || s.isStaff)) return null;
  if (!_attached) {
    _attached = true;
    CrmWebSession.instance.attach(wipeCrmWebStorage);
  }
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => CrmPageScreen(
      target: target,
      surface: crmWebViewSurface(
        // Remove this line (and android_photo_picker.dart) to drop
        // image_picker; iOS uploads do not use it.
        androidPicker: Platform.isAndroid ? pickPhotosForWebView : null,
      ),
    ),
  );
}
