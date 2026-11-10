import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/crm_web/crm_web_target.dart';
import '../../data/web_pass_repository.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import 'crm_web_session.dart';

/// What the web view needs from the screen.
class CrmWebSurfaceArgs {
  final Uri url;

  /// The only host allowed inside the view.
  final String host;

  /// The pass failed or expired, or the page fell back to the web login.
  final VoidCallback onPassFailed;

  /// Any other link: the system browser.
  final Future<void> Function(Uri uri) openExternal;

  const CrmWebSurfaceArgs({
    required this.url,
    required this.host,
    required this.onPassFailed,
    required this.openExternal,
  });
}

typedef CrmWebSurfaceBuilder =
    Widget Function(BuildContext context, CrmWebSurfaceArgs args);

/// One CRM page (Việc của tôi, Nhóm) inside the app (T1): a fresh one-use
/// pass per opening, our host only, and one Vietnamese retry line when the
/// pass fails or expires (never the web login form). Back or ✕ closes it.
class CrmPageScreen extends StatefulWidget {
  final CrmTarget target;
  final CrmWebSurfaceBuilder surface;
  final WebPassRepository repository;
  final CrmWebSession? session;

  const CrmPageScreen({
    super.key,
    required this.target,
    required this.surface,
    this.repository = const WebPassRepository(),
    this.session,
  });

  static const retryText = 'Không mở được trang. Vui lòng thử lại.';

  @override
  State<CrmPageScreen> createState() => _CrmPageScreenState();
}

class _CrmPageScreenState extends State<CrmPageScreen> {
  WebPass? _pass;
  bool _failed = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final attempt = ++_attempt;
    setState(() {
      _pass = null;
      _failed = false;
    });
    try {
      await (widget.session ?? CrmWebSession.instance).beforeOpen();
      final pass = await widget.repository.mint(widget.target);
      if (mounted && attempt == _attempt) setState(() => _pass = pass);
    } catch (e) {
      if (!mounted || attempt != _attempt) return;
      if (e is EmsException && e.statusCode == 401) {
        if (await handleCrmAuthError(context, e)) return;
      }
      if (mounted) setState(() => _failed = true);
    }
  }

  void _passFailed() {
    if (mounted) {
      setState(() {
        _pass = null;
        _failed = true;
      });
    }
  }

  Future<void> _external(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final pass = _pass;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(
        title: Text(widget.target.title),
        backgroundColor: vd.headerTop,
        foregroundColor: vd.onHeader,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Đóng',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      CrmPageScreen.retryText,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: vd.ink),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _open,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : pass == null
          ? const Center(child: CircularProgressIndicator())
          : widget.surface(
              context,
              CrmWebSurfaceArgs(
                url: pass.url,
                host: widget.repository.crmHost,
                onPassFailed: _passFailed,
                openExternal: _external,
              ),
            ),
    );
  }
}
