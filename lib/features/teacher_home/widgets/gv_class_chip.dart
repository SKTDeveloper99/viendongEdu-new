import 'package:flutter/material.dart';

import '../../../core/schedule/next_up.dart' show parseMinutes;
import '../../../theme/vd_tokens.dart';

({String label, Color color}) gvBuoiInfo(String? b, VdTokens t) => switch (b) {
  'S' => (label: 'Sáng', color: t.info),
  'C' => (label: 'Chiều', color: t.warning),
  'T' => (label: 'Tối', color: t.evening),
  _ => (label: '', color: t.inkMuted),
};

// CrmScheduleSlot.toJson() carries no `buoi`, so the Buổi comes from the start
// time exactly like the student home (hour < 12 Sáng, < 18 Chiều, else Tối).
// A `buoi` key, if a caller still supplies one, is only the fallback.
({String label, Color color}) gvBuoiFor(
  String? startRaw,
  String? buoi,
  VdTokens t,
) {
  final start = parseMinutes(startRaw);
  if (start == null) return gvBuoiInfo(buoi, t);
  final hour = start ~/ 60;
  if (hour < 12) return gvBuoiInfo('S', t);
  if (hour < 18) return gvBuoiInfo('C', t);
  return gvBuoiInfo('T', t);
}

class GvClassChip extends StatelessWidget {
  final Map<String, dynamic> data;
  const GvClassChip({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['mhten']?.toString() ?? '';
    final room = data['phongten']?.toString().trim() ?? '';
    final classCode = data['lmhma']?.toString() ?? '';
    final start = data['thoigianbd']?.toString() ?? '';
    final endRaw = data['thoigiankt'] as String? ?? '';
    final end = endRaw.length >= 16 ? endRaw.substring(11, 16) : endRaw;
    final buoi = gvBuoiFor(
      data['thoigianbd']?.toString(),
      data['buoi']?.toString(),
      context.vd,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: context.vd.shadow,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
        border: Border(left: BorderSide(color: buoi.color, width: 5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tên môn + badge buổi
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (buoi.label.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: buoi.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      buoi.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: buoi.color,
                      ),
                    ),
                  ),
              ],
            ),
            // Mã lớp — subtitle
            if (classCode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  classCode,
                  style: TextStyle(fontSize: 11, color: context.vd.ink),
                ),
              ),
            const SizedBox(height: 6),
            // Giờ học
            Row(
              children: [
                Icon(Icons.access_time, size: 13, color: buoi.color),
                const SizedBox(width: 4),
                Text(
                  end.isNotEmpty ? '$start – $end' : start,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: buoi.color,
                  ),
                ),
              ],
            ),
            // Phòng học
            if (room.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.room, size: 13, color: context.vd.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      room,
                      style: TextStyle(fontSize: 12, color: context.vd.ink),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
