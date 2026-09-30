/// Pure "Tiếp theo" logic shared by the student and teacher homes. No Flutter
/// imports, no clock of its own: the caller passes `now`.
library;

enum NextUpPhase { ongoing, upcoming, none }

/// One class of today reduced to what the card needs. Times are minutes since
/// midnight; [endMin] is null when the schedule has no readable end time.
class NextUpEntry {
  final String subject;
  final int startMin;
  final int? endMin;
  final String room;
  final String classCode;
  const NextUpEntry({
    required this.subject,
    required this.startMin,
    this.endMin,
    this.room = '',
    this.classCode = '',
  });
}

class NextUp {
  final NextUpPhase phase;
  final NextUpEntry? entry;

  /// Minutes left (ongoing) or minutes until the start (upcoming).
  final int minutes;
  const NextUp(this.phase, {this.entry, this.minutes = 0});

  static const none = NextUp(NextUpPhase.none);

  String get statusLabel => switch (phase) {
    NextUpPhase.ongoing => 'Đang diễn ra',
    NextUpPhase.upcoming => 'Tiếp theo',
    NextUpPhase.none => '',
  };

  /// "còn 45 phút" / "bắt đầu sau 30 phút" / "lúc 14:30" (from 60 min on).
  String get countdown {
    final e = entry;
    if (e == null) return '';
    if (phase == NextUpPhase.ongoing) return 'còn $minutes phút';
    return minutes >= 60
        ? 'lúc ${formatMinutes(e.startMin)}'
        : 'bắt đầu sau $minutes phút';
  }

  /// "07:30 – 09:30" (just the start when the end is unknown).
  String get timeRange {
    final e = entry;
    if (e == null) return '';
    final end = e.endMin;
    return end == null
        ? formatMinutes(e.startMin)
        : '${formatMinutes(e.startMin)} – ${formatMinutes(end)}';
  }
}

String formatMinutes(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// First `H:mm` / `HH:mm` in [raw] as minutes since midnight; works for
/// "07:30" and for "2026-09-30T07:30:00". Null when there is none.
int? parseMinutes(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/// The class in progress (start ≤ now < end), else the next one later today,
/// else [NextUp.none]. Whole minutes: seconds of [now] are ignored.
NextUp computeNextUp(List<NextUpEntry> entries, DateTime now) {
  final nowMin = now.hour * 60 + now.minute;
  NextUpEntry? ongoing;
  NextUpEntry? upcoming;
  for (final e in entries) {
    final end = e.endMin;
    if (e.startMin <= nowMin) {
      if (end != null && nowMin < end) {
        if (ongoing == null || e.startMin < ongoing.startMin) ongoing = e;
      }
    } else if (upcoming == null || e.startMin < upcoming.startMin) {
      upcoming = e;
    }
  }
  if (ongoing != null) {
    return NextUp(
      NextUpPhase.ongoing,
      entry: ongoing,
      minutes: ongoing.endMin! - nowMin,
    );
  }
  if (upcoming != null) {
    return NextUp(
      NextUpPhase.upcoming,
      entry: upcoming,
      minutes: upcoming.startMin - nowMin,
    );
  }
  return NextUp.none;
}
