import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';
import '../attendance_outbox.dart';

/// "N chờ gửi": how many attendance drafts are queued on this phone.
/// Renders nothing when there are none.
class PendingSendBadge extends StatelessWidget {
  const PendingSendBadge({super.key, this.outbox});

  /// Tests may inject an outbox; the app uses the shared one.
  final AttendanceOutbox? outbox;

  @override
  Widget build(BuildContext context) {
    final box = outbox ?? AttendanceOutbox.instance;
    return ValueListenableBuilder<int>(
      valueListenable: box.pendingCount,
      builder: (context, n, _) {
        if (n <= 0) return const SizedBox.shrink();
        final t = context.vd;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: t.warningSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$n chờ gửi',
            style: TextStyle(
              fontSize: 11,
              color: t.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}
