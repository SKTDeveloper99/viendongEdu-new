import 'package:flutter/material.dart';

import '../models/student_notice.dart';
import '../theme/vd_tokens.dart';

/// Draws the server's `notices` for one screen, in order. Nothing at all (no
/// empty box, no spacing) when there is nothing visible today.
class StudentNoticeList extends StatelessWidget {
  final List<StudentNotice> notices;

  /// Space under the list when it shows something.
  final double gap;

  /// Test clock; production uses the phone clock converted to Vietnam time.
  final DateTime Function()? now;

  const StudentNoticeList({
    super.key,
    required this.notices,
    this.gap = 12,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final shown = visibleStudentNotices(notices, now?.call());
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            StudentNoticeBanner(
              key: ValueKey('notice-${shown[i].id}'),
              level: shown[i].level,
              text: shown[i].text,
            ),
          ],
        ],
      ),
    );
  }
}

/// One notice box. Also used for the app's own date-free debt fallback.
class StudentNoticeBanner extends StatelessWidget {
  final StudentNoticeLevel level;
  final String text;

  const StudentNoticeBanner({
    super.key,
    required this.level,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final (Color tone, IconData icon) = switch (level) {
      StudentNoticeLevel.urgent => (vd.danger, Icons.warning_amber_rounded),
      StudentNoticeLevel.warning => (vd.warning, Icons.error_outline_rounded),
      StudentNoticeLevel.info => (vd.info, Icons.info_outline_rounded),
    };
    return Semantics(
      container: true,
      liveRegion: level == StudentNoticeLevel.urgent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tone.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tone),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 14, height: 1.35, color: vd.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
