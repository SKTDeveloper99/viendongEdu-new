import 'package:flutter/material.dart';

import '../../../models/crm_teacher_class.dart';
import '../../../theme/vd_tokens.dart';

/// One class in the list.
class ClassCard extends StatelessWidget {
  final CrmTeacherClass lop;
  final VoidCallback onTap;
  const ClassCard({super.key, required this.lop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mhten = lop.subjectName ?? '';
    final mhma = lop.subjectCode ?? '';
    final sotinchi = lop.credits ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: context.vd.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: context.vd.shadow,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: context.vd.ink,
                        ),
                        children: [
                          TextSpan(
                            text: mhma,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: context.vd.primary,
                            ),
                          ),
                          const TextSpan(text: ' · '),
                          TextSpan(
                            text: mhten,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lop.sectionCode,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.vd.ink,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (sotinchi > 0) ...[
                          Icon(
                            Icons.school_outlined,
                            size: 13,
                            color: context.vd.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$sotinchi tín chỉ',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.vd.inkMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Icon(
                          Icons.people_outline,
                          size: 13,
                          color: context.vd.inkMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${lop.enrolledStudents} SV',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.vd.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: context.vd.inkFaint, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
