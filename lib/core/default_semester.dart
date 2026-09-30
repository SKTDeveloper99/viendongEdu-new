/// One place that decides which semester a screen opens on, so no screen
/// trusts the order of the server's list (it may contain future semesters).
///
/// Order of preference:
///   1. the item whose code equals [currentCode] (`current_semester` of
///      `GET /api/teacher/me/overview`);
///   2. the item with the latest start date that is <= [today];
///   3. the first item.
/// Returns null only for an empty list.
T? pickDefaultSemester<T>(
  List<T> items, {
  required String Function(T) codeOf,
  DateTime? Function(T)? startOf,
  String? currentCode,
  DateTime? today,
}) {
  if (items.isEmpty) return null;
  final cur = currentCode?.trim() ?? '';
  if (cur.isNotEmpty) {
    for (final s in items) {
      if (codeOf(s) == cur) return s;
    }
  }
  if (startOf != null) {
    final now = today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    T? best;
    DateTime? bestStart;
    for (final s in items) {
      final st = startOf(s);
      if (st == null) continue;
      final d = DateTime(st.year, st.month, st.day);
      if (d.isAfter(day)) continue;
      if (bestStart == null || d.isAfter(bestStart)) {
        best = s;
        bestStart = d;
      }
    }
    if (best != null) return best;
  }
  return items.first;
}

/// Parses `yyyy-MM-dd...` (API date strings); null when unparsable.
DateTime? parseSemesterDate(String? raw) {
  if (raw == null || raw.length < 10) return null;
  return DateTime.tryParse(raw.substring(0, 10));
}
