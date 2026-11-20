import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/vd_tokens.dart';

/// Green notice at the top of the screen, below the status bar.
void showSuccessSnack(
  BuildContext context,
  String msg, {
  Duration duration = const Duration(seconds: 3),
}) => _showTopNotice(
  context,
  msg,
  Icons.check_circle_rounded,
  context.vd.success,
  duration,
);

/// Red notice at the top of the screen, below the status bar.
void showErrorSnack(
  BuildContext context,
  String msg, {
  Duration duration = const Duration(seconds: 4),
}) => _showTopNotice(
  context,
  msg,
  Icons.error_rounded,
  context.vd.danger,
  duration,
);

// The notice lives in the app's top overlay, anchored under the safe area and
// growing downward: a floating SnackBar pushed to the top sat under the status
// bar and the camera cut-out on screens with a floating button (the Scaffold
// lifts it above the button) and ran off the top when it had several lines.
OverlayEntry? _current;

void _showTopNotice(
  BuildContext context,
  String msg,
  IconData icon,
  Color color,
  Duration duration,
) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final onColor = context.vd.onPrimary;
  _dismissCurrent();
  if (overlay == null) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
    return;
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopNotice(
      msg: msg,
      icon: icon,
      color: color,
      onColor: onColor,
      duration: duration,
      onDone: () {
        if (identical(_current, entry)) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

void _dismissCurrent() {
  final e = _current;
  _current = null;
  if (e != null && e.mounted) e.remove();
}

class _TopNotice extends StatefulWidget {
  final String msg;
  final IconData icon;
  final Color color;
  final Color onColor;
  final Duration duration;
  final VoidCallback onDone;
  const _TopNotice({
    required this.msg,
    required this.icon,
    required this.color,
    required this.onColor,
    required this.duration,
    required this.onDone,
  });

  @override
  State<_TopNotice> createState() => _TopNoticeState();
}

class _TopNoticeState extends State<_TopNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    await _fade.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: FadeTransition(
            opacity: _fade,
            child: Dismissible(
              key: const ValueKey('top-notice'),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDone(),
              child: Material(
                color: widget.color,
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _close,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(widget.icon, color: widget.onColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.msg,
                            style: TextStyle(
                              color: widget.onColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
