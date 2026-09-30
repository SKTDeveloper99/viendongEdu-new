import 'package:flutter/material.dart';

import '../../../models/crm_teacher_class.dart';
import '../class_manager_format.dart';
import '../../../theme/vd_tokens.dart';

/// "Thông tin" tab: static facts of the class.
class ClassInfoTab extends StatelessWidget {
  final CrmTeacherClass lop;
  const ClassInfoTab({super.key, required this.lop});

  @override
  Widget build(BuildContext context) {
    final sotinchi = lop.credits ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _DetailRow(
          icon: Icons.class_outlined,
          label: 'Mã lớp',
          value: lop.sectionCode,
        ),
        const SizedBox(height: 12),
        if (sotinchi > 0) ...[
          _DetailRow(
            icon: Icons.school_outlined,
            label: 'Tín chỉ',
            value: '$sotinchi TC',
          ),
          const SizedBox(height: 12),
        ],
        if ((lop.room ?? '').isNotEmpty) ...[
          _DetailRow(
            icon: Icons.room_outlined,
            label: 'Phòng',
            value: lop.room!,
          ),
          const SizedBox(height: 12),
        ],
        _DetailRow(
          icon: Icons.people_outline,
          label: 'Sĩ số',
          value: '${lop.enrolledStudents} sinh viên',
        ),
        const SizedBox(height: 12),
        if ((lop.ngayBatDau ?? '').isNotEmpty ||
            (lop.ngayKetThuc ?? '').isNotEmpty) ...[
          _DetailRow(
            icon: Icons.date_range_outlined,
            label: 'Thời gian',
            value: '${fmtDate(lop.ngayBatDau)} – ${fmtDate(lop.ngayKetThuc)}',
          ),
          const SizedBox(height: 12),
        ],
        if ((lop.ngayThi ?? '').isNotEmpty)
          _DetailRow(
            icon: Icons.event_note_outlined,
            label: 'Ngày thi',
            value: fmtDate(lop.ngayThi),
          ),
        // Tỷ lệ điểm chuyên cần/giữa kỳ/cuối kỳ (bản IMS cũ có donut
        // theo % trọng số) KHÔNG có tương đương trong CRM
        // (`sections`/`subjects` không lưu trọng số điểm theo lớp) —
        // bỏ thay vì bịa số. TODO(A4 hoặc bot điểm): thêm nếu/khi CRM
        // có bảng trọng số điểm.
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.vd.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: context.vd.inkMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}
