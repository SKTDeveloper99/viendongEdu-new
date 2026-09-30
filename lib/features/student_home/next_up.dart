import '../../core/schedule/next_up.dart';
import '../../models/crm_student_schedule.dart';

/// Shown when nothing is left today.
const studentNextUpEmpty = 'Hôm nay bạn không còn tiết nào';

/// "Tiếp theo" card state from today's classes (already filtered to today).
NextUp nextUp(List<CrmScheduleItem> today, DateTime now) {
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
  return computeNextUp(entries, now);
}
