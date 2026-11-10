import 'package:flutter/material.dart';

import '../../../models/exam_status_models.dart';
import '../../../models/teacher_care_student.dart';
import '../../../theme/vd_tokens.dart';
import '../care_format.dart';
import 'care_card.dart';

/// "Học phí" for ONE student (owner 2026-11-10, P-03): exam-gate status,
/// the current term (owed, paid, remaining) and all terms (LAW M-54 one
/// number). Unknown reads exactly "Đang đối chiếu", never 0. No list, no
/// total: figures arrive only with the one-student read.
class MoneyCard extends StatelessWidget {
  final TeacherCareStudent student;

  /// True while the one-student read has not answered yet (list copy shown).
  final bool loadingFigures;
  const MoneyCard({
    super.key,
    required this.student,
    this.loadingFigures = false,
  });

  @override
  Widget build(BuildContext context) {
    final money = student.money;
    final term = student.term;
    final vd = context.vd;
    final gate = ExamStudentStatus(
      mssv: student.mssv,
      fullName: student.name,
      status: student.examStatus,
      owesSemesters: student.examOwesSemesters,
    );
    final waiting = money.known && !money.hasFigures;
    final pending = loadingFigures
        ? 'Đang tải…'
        : 'Chưa tải được, kéo để tải lại';
    return CareCard(
      title: 'Học phí',
      children: [
        CareLine(
          'Dự thi',
          gate.label,
          valueColor: switch (gate.status) {
            ExamMoneyStatus.allowed => vd.success,
            ExamMoneyStatus.owes => vd.danger,
            ExamMoneyStatus.noData => null,
          },
        ),
        if (gate.status == ExamMoneyStatus.noData)
          const CareLine('', 'Theo quy định: vẫn được thi'),
        if (term.known) ...[
          CareLine(
            'Học kỳ ${term.semesterCode ?? 'hiện tại'} · phải nộp',
            formatVnd(term.owed!),
          ),
          CareLine('Học kỳ này · đã nộp', formatVnd(term.paid!)),
          CareLine(
            'Học kỳ này · còn lại',
            formatVnd(term.remaining!),
            valueColor: term.remaining! > 0 ? vd.danger : vd.success,
          ),
        ] else
          CareLine('Học kỳ hiện tại', waiting ? pending : unknownText),
        if (!money.known)
          const CareLine('Tất cả học kỳ', unknownText)
        else if (waiting)
          CareLine('Tất cả học kỳ', pending)
        else ...[
          CareLine('Tất cả học kỳ · phải nộp', formatVnd(money.owedTotal!)),
          CareLine('Tất cả học kỳ · đã nộp', formatVnd(money.paid!)),
          CareLine(
            'Tất cả học kỳ · còn nợ',
            money.balance! > 0
                ? formatVnd(money.balance!)
                : money.overpaid
                ? 'Đã đóng dư'
                : 'Đã đóng đủ',
            valueColor: money.balance! > 0 ? vd.danger : vd.success,
          ),
        ],
        if (money.asOf != null)
          CareLine(
            money.stale ? 'Lần cập nhật gần nhất' : 'Cập nhật lúc',
            formatCareTime(money.asOf!),
          ),
      ],
    );
  }
}

/// Red reminder at the top of a student who owes (no stale exam date).
class OweBanner extends StatelessWidget {
  const OweBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.vd.dangerSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Còn nợ học phí. Cần đóng trước buổi thi gần nhất để được dự thi.',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: context.vd.danger,
          height: 1.4,
        ),
      ),
    );
  }
}
