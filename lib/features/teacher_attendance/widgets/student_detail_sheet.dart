import 'package:flutter/material.dart';

import '../../../services/ems_api_service.dart';
import '../attendance_colors.dart';
import '../attendance_format.dart';

/// Chạm vào học viên: xem giờ quẹt cổng chính xác (tới giây) và trạng thái
/// hiện tại, để giáo viên đối chiếu khi học viên khiếu nại "em có quẹt mà".
void showStudentDetailSheet(
  BuildContext context, {
  required EmsRosterStudent student,
  required String? mark,
  required DateTime? scanSyncedAt,
}) {
  final s = student;
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.fullName,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            s.mssv + (s.classCode == null ? '' : ' • ${s.classCode}'),
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const Divider(height: 24),
          _DetailRow(
            icon: Icons.sensor_door_outlined,
            label: 'Quẹt cổng',
            value: !s.scanned
                ? 'Chưa quẹt hôm nay (không phải vắng)'
                : s.scannedAt == null
                ? 'Đã quẹt (không có giờ)'
                : schoolHhmmss(s.scannedAt!),
            color: s.scanned ? attendanceGreen : Colors.grey[600]!,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.how_to_reg_outlined,
            label: 'Điểm danh',
            value: markLabel(mark),
            color: mark == 'present'
                ? attendanceGreen
                : mark == 'absent'
                ? attendanceRed
                : Colors.grey[700]!,
          ),
          if (scanSyncedAt != null) ...[
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.sync,
              label: 'Lấy quẹt cổng lúc',
              value: schoolHhmmss(scanSyncedAt),
              color: Colors.grey[600]!,
            ),
          ],
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      const Spacer(),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    ],
  );
}
