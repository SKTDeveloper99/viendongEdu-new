import 'package:flutter/material.dart';

import '../../../models/crm_teacher_class.dart';

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
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
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        children: [
                          TextSpan(
                            text: mhma,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF444444),
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (sotinchi > 0) ...[
                          const Icon(
                            Icons.school_outlined,
                            size: 13,
                            color: Color(0xFF555555),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$sotinchi tín chỉ',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF555555),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        const Icon(
                          Icons.people_outline,
                          size: 13,
                          color: Color(0xFF555555),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${lop.enrolledStudents} SV',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
