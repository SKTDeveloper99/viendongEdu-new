import 'package:flutter/material.dart';

import '../models/crm_student_schedule.dart';
import '../theme/vd_tokens.dart';

/// LAW A-29: what a student card says about its Buổi học change, or null.
/// (badge label, badge colour, one line of detail)
({String badge, Color color, String? line})? buoiChangeLook(
  CrmBuoiChange? c,
  VdTokens t,
) {
  if (c == null) return null;
  if (c.isCancelled) {
    final moved = c.movedTo != null
        ? 'Dời sang ${CrmBuoiChange.ddmm(c.movedTo)}${c.movedToStart != null ? ' lúc ${c.movedToStart}' : ''}'
        : null;
    final why = (c.reason ?? '').trim();
    final line = [if (why.isNotEmpty && moved == null) 'Lý do: $why', ?moved].join(' · ');
    return (badge: 'Nghỉ', color: t.inkMuted, line: line.isEmpty ? null : line);
  }
  if (c.isMakeup) {
    return (
      badge: 'Học bù',
      color: t.success,
      line: c.makeupFor != null ? 'Bù cho buổi ${CrmBuoiChange.ddmm(c.makeupFor)}' : null,
    );
  }
  return (badge: 'Đổi lịch', color: t.info, line: 'Phòng, giờ hoặc giảng viên đã đổi cho buổi này');
}

/// The small detail line under a card.
class BuoiChangeText extends StatelessWidget {
  final String text;
  const BuoiChangeText(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: TextStyle(fontSize: 11.5, color: context.vd.inkMuted, fontWeight: FontWeight.w500),
    ),
  );
}
