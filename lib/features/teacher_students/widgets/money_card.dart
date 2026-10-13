import 'package:flutter/material.dart';

import '../../../models/teacher_care_student.dart';
import '../../../theme/vd_tokens.dart';
import '../care_format.dart';
import 'care_card.dart';

/// "Học phí" — the one number of LAW M-54. Unknown shows exactly
/// "Đang đối chiếu" and no amount.
class MoneyCard extends StatelessWidget {
  final CareMoney money;
  const MoneyCard({super.key, required this.money});

  @override
  Widget build(BuildContext context) {
    if (!money.known) {
      return const CareCard(
        title: 'Học phí',
        children: [CareLine('Tình trạng', unknownText)],
      );
    }
    final balance = money.balance!;
    return CareCard(
      title: 'Học phí',
      children: [
        CareLine('Phải nộp', formatVnd(money.owedTotal!)),
        CareLine('Đã nộp', formatVnd(money.paid!)),
        CareLine(
          'Còn nợ',
          balance > 0 ? formatVnd(balance) : 'Đã đóng đủ',
          valueColor: balance > 0 ? context.vd.danger : context.vd.success,
        ),
      ],
    );
  }
}

/// Red reminder at the top of a student who owes before the midterm.
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
        'Còn nợ học phí. Cần đóng trước kỳ thi giữa kỳ $midtermLabel '
        'để được dự thi.',
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
