import 'package:flutter/material.dart';

import '../../../models/exam_status_models.dart';
import '../../../theme/vd_tokens.dart';

/// One student's exam status: "Được thi", "Còn nợ HK …" or "Chưa có dữ
/// liệu" (with "Theo quy định: vẫn được thi", M-32). Never an amount.
class ExamStatusRow extends StatelessWidget {
  final ExamStudentStatus student;
  final int index;
  const ExamStatusRow({super.key, required this.student, required this.index});

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final (Color fg, Color bg) = switch (student.status) {
      ExamMoneyStatus.allowed => (vd.success, vd.successSoft),
      ExamMoneyStatus.owes => (vd.danger, vd.dangerSoft),
      ExamMoneyStatus.noData => (vd.inkMuted, vd.surfaceAlt),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text('$index', style: TextStyle(color: vd.inkMuted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName.isEmpty ? student.mssv : student.fullName,
                  style: TextStyle(fontWeight: FontWeight.w600, color: vd.ink),
                ),
                Text(
                  student.mssv,
                  style: TextStyle(fontSize: 12, color: vd.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    student.label,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
                if (student.status == ExamMoneyStatus.noData)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Theo quy định: vẫn được thi',
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 11, color: vd.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
