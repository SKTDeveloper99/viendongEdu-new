import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';

/// No class today, but some subjects have no published timetable yet: say
/// that instead of "no class 🎉", and lead to Lịch học where they are listed.
class UnpublishedScheduleNote extends StatelessWidget {
  final int count;
  const UnpublishedScheduleNote({super.key, required this.count});

  static String text(int count) => 'Lịch học của $count môn chưa được công bố.';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Semantics(
        button: true,
        label: '${text(count)} Mở Lịch học',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pushNamed(context, '/schedule'),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.vd.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: context.vd.shadow,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.event_busy, size: 18, color: context.vd.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text(count),
                    style: TextStyle(fontSize: 13, color: context.vd.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Xem Lịch học',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.vd.primary,
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: context.vd.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
