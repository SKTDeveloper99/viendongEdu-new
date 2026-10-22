import 'package:flutter/material.dart';
import '../models/crm_student_exams.dart';
import '../theme/vd_tokens.dart';

class ExamItem {
  final CrmStudentExam exam;
  const ExamItem(this.exam);

  DateTime? get ngayThi => exam.examDate;
  String get gioBatDau => exam.startTime.isEmpty ? '?' : exam.startTime;
  int? get thoiGian => exam.durationMinutes;
  // `room` is frequently null in the CRM's IMS mirror (documented data
  // quality gap, not a join bug) — shown as "—" rather than blank.
  String get phongten =>
      exam.room?.trim().isNotEmpty == true ? exam.room!.trim() : '—';
  String get loaiThi => exam.examType;
  String get mhten => exam.subjectName;
  String get hkma => exam.semesterCode;
  String get hkten => semesterCodeLabel(exam.semesterCode);

  String get ngayThiFormatted => exam.examDateFormatted;
}

// ── Screen ───────────────────────────────────────────────
class StudentExamCard extends StatelessWidget {
  final ExamItem exam;
  const StudentExamCard({super.key, required this.exam});

  Color _loaiColor(BuildContext context) =>
      exam.loaiThi.contains('Giữa') ? context.vd.info : context.vd.accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.vd.shadow,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Thanh màu trái
          Container(
            width: 5,
            height: 100,
            decoration: BoxDecoration(
              color: _loaiColor(context),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tên môn + badge loại thi
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          exam.mhten,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: _loaiColor(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          exam.loaiThi,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _loaiColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Ngày + giờ
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 13,
                        color: context.vd.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        exam.ngayThiFormatted,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: context.vd.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        exam.gioBatDau,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: context.vd.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        exam.thoiGian == null ? '—' : '${exam.thoiGian} phút',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Phòng thi
                  Row(
                    children: [
                      Icon(Icons.room, size: 13, color: context.vd.primary),
                      const SizedBox(width: 4),
                      Text(
                        exam.phongten,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
