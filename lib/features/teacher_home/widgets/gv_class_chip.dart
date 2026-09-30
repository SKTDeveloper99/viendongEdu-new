import 'package:flutter/material.dart';

import '../../../theme/vd_theme.dart';

({String label, Color color}) gvBuoiInfo(String? b) => switch (b) {
  'S' => (label: 'Sáng', color: const Color(0xFF2196F3)),
  'C' => (label: 'Chiều', color: const Color(0xFFFF9800)),
  'T' => (label: 'Tối', color: const Color(0xFF9C27B0)),
  _ => (label: '', color: Colors.grey),
};

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
    final buoi = gvBuoiInfo(data['buoi']?.toString());

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF444444),
                  ),
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
                  const Icon(Icons.room, size: 13, color: VdColors.terracotta),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      room,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
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
