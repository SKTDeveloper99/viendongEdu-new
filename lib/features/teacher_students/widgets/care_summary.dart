import 'package:flutter/material.dart';

import '../../../models/teacher_care_student.dart';
import '../../../theme/vd_tokens.dart';
import '../care_format.dart';
import 'care_layout.dart';

/// The two counts at the top of "Sinh viên của tôi". Counts of students
/// only — never a sum of money.
class CareSummary extends StatelessWidget {
  final int owing;
  final int attention;
  const CareSummary({super.key, required this.owing, required this.attention});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Tile(
            value: owing,
            label: 'sinh viên còn nợ học phí trước giữa kỳ $midtermLabel',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Tile(value: attention, label: 'sinh viên cần chú ý'),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final int value;
  final String label;
  const _Tile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.vd.surface,
        border: Border.all(color: context.vd.hairline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: value > 0 ? context.vd.danger : context.vd.ink,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 16, color: context.vd.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Small status of one student in a class list.
List<Widget> studentPills(TeacherCareStudent s) => [
  if (s.money.owes) const CarePill('Còn nợ học phí', tone: CareTone.danger),
  if (!s.money.known)
    const CarePill('Học phí: $unknownText', tone: CareTone.neutral),
  if (s.needsAttention) const CarePill('Cần chú ý', tone: CareTone.warning),
];
