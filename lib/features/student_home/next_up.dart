import '../../core/schedule/next_up.dart';
import '../../models/crm_student_schedule.dart';
import '../../models/crm_student_exams.dart';

List<CrmStudentExam> upcomingExams(List<CrmStudentExam> exams, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final end = DateTime(now.year, now.month, now.day + 7);
  final seen = <String>{};
  return exams
      .where(
        (e) =>
            e.examDate != null &&
            !e.examDate!.isBefore(today) &&
            !e.examDate!.isAfter(end) &&
            (e.examId.isEmpty || seen.add(e.examId)),
      )
      .toList()
    ..sort((a, b) {
      final date = a.examDate!.compareTo(b.examDate!);
      return date == 0 ? a.startTime.compareTo(b.startTime) : date;
    });
}

/// Shown when nothing is left today.
const studentNextUpEmpty = 'Hôm nay bạn không còn tiết nào';

/// "Tiếp theo" card state from today's classes (already filtered to today).
NextUp nextUp(
  List<CrmScheduleItem> today,
  DateTime now, {
  List<CrmStudentExam> exams = const [],
}) {
  final entries = <NextUpEntry>[];
  for (final c in today) {
    final start = parseMinutes(c.startTime);
    if (start == null) continue;
    entries.add(
      NextUpEntry(
        subject: c.subjectName,
        startMin: start,
        endMin: parseMinutes(c.endTime),
        room: c.room.trim(),
        classCode: c.sectionCode,
      ),
    );
  }
  for (final exam in exams.where((e) => e.occursOn(now))) {
    final start = parseMinutes(exam.startTime);
    if (start == null) continue;
    entries.add(
      NextUpEntry(
        subject: 'Lịch thi · ${exam.subjectName}',
        startMin: start,
        endMin: exam.durationMinutes == null
            ? null
            : start + exam.durationMinutes!,
        room: exam.room ?? '',
      ),
    );
  }
  return computeNextUp(entries, now);
}
