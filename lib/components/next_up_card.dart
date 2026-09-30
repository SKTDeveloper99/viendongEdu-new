import 'package:flutter/material.dart';

import '../core/schedule/next_up.dart';
import '../theme/vd_tokens.dart';
import 'vd_fade_in.dart';

/// "Tiếp theo" hero card at the top of both homes: the class in progress or
/// the next one today, or a friendly empty state. Display-only.
///
/// [onAttendance] (teacher) adds a filled "Điểm danh" button.
class NextUpCard extends StatelessWidget {
  final NextUp state;
  final String emptyText;
  final bool showClassCode;
  final VoidCallback? onAttendance;
  const NextUpCard({
    super.key,
    required this.state,
    required this.emptyText,
    this.showClassCode = false,
    this.onAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.vd;
    return VdFadeIn(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.hairline),
          boxShadow: [
            BoxShadow(
              color: t.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: state.entry == null ? _empty(t) : _filled(context, t),
      ),
    );
  }

  Widget _empty(VdTokens t) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: t.accentSoft, shape: BoxShape.circle),
        child: Icon(Icons.event_available, color: t.primary, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          emptyText,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: t.ink,
          ),
        ),
      ),
    ],
  );

  Widget _filled(BuildContext context, VdTokens t) {
    final e = state.entry!;
    final live = state.phase == NextUpPhase.ongoing;
    final tone = live ? t.success : t.primary;
    final toneSoft = live ? t.successSoft : t.accentSoft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: toneSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: tone),
                  const SizedBox(width: 6),
                  Text(
                    state.statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tone,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.countdown,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          e.subject,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 8),
        _line(t, Icons.access_time, state.timeRange, strong: true),
        if (e.room.isNotEmpty) _line(t, Icons.room_outlined, e.room),
        if (showClassCode && e.classCode.isNotEmpty)
          _line(t, Icons.class_outlined, e.classCode),
        if (onAttendance != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAttendance,
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Điểm danh'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _line(VdTokens t, IconData icon, String text, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: t.inkMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
                  color: strong ? t.ink : t.inkMuted,
                ),
              ),
            ),
          ],
        ),
      );
}
