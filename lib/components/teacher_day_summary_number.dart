import 'package:flutter/material.dart';

import '../theme/vd_tokens.dart';

class TeacherDaySummaryNumber extends StatelessWidget {
  final String value;
  final String label;
  const TeacherDaySummaryNumber({
    super.key,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: context.vd.onPrimary,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.vd.onPrimary.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    ),
  );
}
