import 'package:flutter/material.dart';

import '../../../services/ems_api_service.dart';
import '../attendance_format.dart';
import '../../../theme/vd_tokens.dart';

/// One roster student: name, MSSV, gate scan, and the Có / Vắng / more marks.
class StudentRow extends StatelessWidget {
  const StudentRow({
    super.key,
    required this.student,
    required this.mark,
    required this.onSelect,
    required this.onOpenDetail,
  });

  final EmsRosterStudent student;
  final String? mark;
  final void Function(String? status) onSelect;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final s = student;
    return Material(
      color: context.vd.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Expanded(child: _identity(context, s)),
              _Pill(
                label: 'Có',
                selected: mark == 'present',
                color: context.vd.success,
                onTap: () => onSelect('present'),
              ),
              const SizedBox(width: 6),
              _Pill(
                label: 'Vắng',
                selected: mark == 'absent',
                color: context.vd.danger,
                onTap: () => onSelect('absent'),
              ),
              PopupMenuButton<String>(
                tooltip: 'Trạng thái khác',
                onSelected: (value) =>
                    onSelect(value == 'unmarked' ? null : value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'late', child: Text('Đi trễ')),
                  PopupMenuItem(value: 'excused', child: Text('Vắng có phép')),
                  PopupMenuItem(
                    value: 'unmarked',
                    child: Text('Chưa điểm danh'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identity(BuildContext context, EmsRosterStudent s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        s.fullName,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 2),
      Row(
        children: [
          Text(s.mssv, style: TextStyle(fontSize: 11, color: context.vd.inkMuted)),
          if (s.scanned) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.sensor_door_outlined,
              size: 13,
              color: context.vd.success,
            ),
            const SizedBox(width: 2),
            Text(
              s.scannedAt == null
                  ? 'đã quẹt cổng'
                  : 'quẹt ${schoolHhmm(s.scannedAt!)}',
              style: TextStyle(fontSize: 11, color: context.vd.success),
            ),
          ],
        ],
      ),
      if (mark == null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'chưa điểm danh',
            style: TextStyle(
              fontSize: 11,
              color: context.vd.inkMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : context.vd.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? context.vd.onPrimary : context.vd.inkMuted,
          ),
        ),
      ),
    );
  }
}
