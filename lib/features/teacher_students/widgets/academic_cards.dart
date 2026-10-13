import 'package:flutter/material.dart';

import '../../../models/teacher_care_student.dart';
import '../../../theme/vd_tokens.dart';
import '../care_format.dart';
import 'care_card.dart';

/// "Điểm" of one class. Stale grade data shows "Đang đối chiếu".
class GradesCard extends StatelessWidget {
  final CareSection section;
  final bool fresh;
  final String title;
  const GradesCard({
    super.key,
    required this.section,
    required this.fresh,
    this.title = 'Điểm môn này',
  });

  @override
  Widget build(BuildContext context) {
    return CareCard(
      title: title,
      children: fresh && section.scoresReadable
          ? [
              CareLine('Giữa kỳ', formatScore(section.midterm)),
              CareLine('Cuối kỳ', formatScore(section.finalScore)),
            ]
          : const [CareLine('Điểm', unknownText)],
    );
  }
}

/// "Chuyên cần" of one class. A session with no mark is "Chờ giáo viên xác
/// nhận" and is never counted as absent.
class AttendanceCard extends StatelessWidget {
  final CareSection section;
  final bool fresh;
  final String title;
  const AttendanceCard({
    super.key,
    required this.section,
    required this.fresh,
    this.title = 'Chuyên cần',
  });

  @override
  Widget build(BuildContext context) {
    if (!fresh || !section.attendanceKnown) {
      return CareCard(
        title: title,
        children: const [CareLine('Điểm danh', unknownText)],
      );
    }
    final s = section;
    return CareCard(
      title: title,
      children: [
        CareLine('Có mặt', '${s.present} buổi'),
        CareLine(
          'Vắng',
          '${s.absent} buổi',
          valueColor: s.absent! > 0 ? context.vd.danger : null,
        ),
        if (s.unrecorded! > 0)
          CareLine('Chờ giáo viên xác nhận', '${s.unrecorded} buổi'),
        if (s.conflicts! > 0) CareLine(unknownText, '${s.conflicts} buổi'),
        if (s.unrecorded! > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Buổi chưa có điểm danh không tính là vắng.',
              style: TextStyle(fontSize: 16, color: context.vd.inkMuted),
            ),
          ),
      ],
    );
  }
}
