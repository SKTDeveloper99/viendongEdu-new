import '../../core/schedule/buoi.dart';
import '../../core/schedule/next_up.dart';

/// Shown when nothing is left today.
const teacherNextUpEmpty = 'Hôm nay thầy/cô không còn tiết dạy nào';

/// "Tiếp theo" card state from today's sessions (the `toJson()` maps the home
/// already holds: `mhten`, `lmhma`, `phongten`, `thoigianbd`, `thoigiankt`).
NextUp nextUp(List<Map<String, dynamic>> today, DateTime now) {
  final entries = <NextUpEntry>[];
  for (final c in today) {
    // A meeting báo nghỉ (LAW A-29) is never "Tiếp theo".
    final buoi = teacherBuoiOf(c);
    if (buoi.isCancelled) continue;
    final start = parseMinutes(c['thoigianbd']?.toString());
    if (start == null) continue;
    entries.add(
      NextUpEntry(
        subject: buoi.title,
        startMin: start,
        endMin: parseMinutes(c['thoigiankt']?.toString()),
        room: c['phongten']?.toString().trim() ?? '',
        classCode: c['lmhma']?.toString() ?? '',
      ),
    );
  }
  return computeNextUp(entries, now);
}
