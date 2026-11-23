/// Buổi học state of one dated class meeting (server LAW A-29), read from a
/// teacher schedule row (`CrmScheduleSlot.toJson()` map). Pure, no Flutter.
///
/// New servers send `buoi_status` (bao_nghi | hoc_bu | day_thay |
/// co_nguoi_day_thay), `buoi_note` and the plain subject `mhten_goc`. For
/// rows without them (older server, cached copy) the state is read from
/// `baonghiyn` and the words the server puts in front of the subject for
/// builds up to 6.0.9 (5): "Báo nghỉ · ", "Học bù · ", "Dạy thay · ",
/// "Dạy thay: (tên) · ". The card always shows the plain subject.
library;

enum BuoiKind { normal, cancelled, makeup, standIn, coveredBy }

class TeacherBuoi {
  final BuoiKind kind;

  /// The subject without any prefix.
  final String title;

  /// Reason (cancelled) or the stand-in's name (coveredBy).
  final String? note;
  const TeacherBuoi(this.kind, this.title, [this.note]);

  bool get isCancelled => kind == BuoiKind.cancelled;
}

final RegExp _prefix = RegExp(r'^(Báo nghỉ|Học bù|Dạy thay(?:: ([^·]+))?) · ');

TeacherBuoi teacherBuoiOf(Map<String, dynamic> d) {
  final raw = d['mhten']?.toString() ?? '';
  final m = _prefix.firstMatch(raw);
  final stripped = m == null ? raw : raw.substring(m.end);
  final goc = d['mhten_goc']?.toString();
  final title = (goc != null && goc.isNotEmpty) ? goc : stripped;
  final note = d['buoi_note']?.toString();
  final noteOrNull = (note == null || note.trim().isEmpty) ? null : note.trim();
  final b = d['baonghiyn'];
  final cancelled = b == true || b == 1 || b == '1' || b == 'true';
  switch (d['buoi_status']?.toString()) {
    case 'bao_nghi':
      return TeacherBuoi(BuoiKind.cancelled, title, noteOrNull);
    case 'hoc_bu':
      return TeacherBuoi(BuoiKind.makeup, title);
    case 'day_thay':
      return TeacherBuoi(BuoiKind.standIn, title);
    case 'co_nguoi_day_thay':
      return TeacherBuoi(BuoiKind.coveredBy, title, noteOrNull);
  }
  if (cancelled) return TeacherBuoi(BuoiKind.cancelled, title, noteOrNull);
  if (m == null) return TeacherBuoi(BuoiKind.normal, title);
  final word = m.group(1)!;
  if (word == 'Học bù') return TeacherBuoi(BuoiKind.makeup, title);
  if (word == 'Báo nghỉ') return TeacherBuoi(BuoiKind.cancelled, title);
  final who = m.group(2)?.trim();
  if (who != null && who.isNotEmpty) {
    return TeacherBuoi(BuoiKind.coveredBy, title, who);
  }
  return TeacherBuoi(BuoiKind.standIn, title);
}
