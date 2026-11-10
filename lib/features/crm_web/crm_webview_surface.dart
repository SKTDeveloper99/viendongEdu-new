import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/crm_web/crm_web_policy.dart';
import 'crm_page_screen.dart';

// The only file that uses webview_flutter (owner to confirm before any
// build). The rest of T1 talks to it through [CrmWebSurfaceBuilder].

typedef AndroidFilePicker =
    Future<List<String>> Function(FileSelectorParams params);

/// Builds the in-app web view: JavaScript on (only our host ever loads, see
/// [crmNavigation]); no JavaScript channel; no file access from URLs; other
/// hosts leave the view for the system browser.
CrmWebSurfaceBuilder crmWebViewSurface({AndroidFilePicker? androidPicker}) =>
    (context, args) => _CrmWebView(args: args, androidPicker: androidPicker);

/// Clears the view's cookies, local storage and cache (logout, new token).
Future<void> wipeCrmWebStorage() async {
  await WebViewCookieManager().clearCookies();
  final c = WebViewController();
  await c.clearLocalStorage();
  await c.clearCache();
}

class _CrmWebView extends StatefulWidget {
  final CrmWebSurfaceArgs args;
  final AndroidFilePicker? androidPicker;
  const _CrmWebView({required this.args, this.androidPicker});

  @override
  State<_CrmWebView> createState() => _CrmWebViewState();
}

class _CrmWebViewState extends State<_CrmWebView> {
  late final WebViewController _controller = _build();
  int _progress = 0;

  WebViewController _build() {
    final a = widget.args;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (req) {
            final uri = Uri.tryParse(req.url);
            final nav = uri == null
                ? CrmNav.block
                : crmNavigation(uri, host: a.host);
            switch (nav) {
              case CrmNav.allow:
                return NavigationDecision.navigate;
              case CrmNav.passFailed:
                a.onPassFailed();
              case CrmNav.external:
                unawaited(a.openExternal(uri!));
              case CrmNav.block:
                break;
            }
            return NavigationDecision.prevent;
          },
          onHttpError: (e) {
            // The page itself was refused (expired web session): retry line.
            final code = e.response?.statusCode;
            if ((code == 401 || code == 403) &&
                e.request?.uri.host == a.host &&
                e.request?.uri.path == a.url.path) {
              a.onPassFailed();
            }
          },
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        ),
      );
    final platform = c.platform;
    if (platform is AndroidWebViewController) {
      unawaited(platform.setAllowFileAccess(false));
      unawaited(platform.setAllowContentAccess(false));
      unawaited(platform.setGeolocationEnabled(false));
      final picker = widget.androidPicker;
      if (picker != null) unawaited(platform.setOnShowFileSelector(picker));
    }
    unawaited(c.loadRequest(a.url));
    return c;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_progress < 100)
          LinearProgressIndicator(
            value: _progress == 0 ? null : _progress / 100,
          ),
        Expanded(child: WebViewWidget(controller: _controller)),
      ],
    );
  }
}
