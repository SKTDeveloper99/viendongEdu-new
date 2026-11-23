/// One dated change to a class meeting (server LAW A-29, `buoi_changes`).
/// status: cancelled | makeup | changed.
class CrmBuoiChange {
  final String date;
  final String sectionCode;
  final String status;
  final String subjectName;
  final String? plannedStart;
  final String? startTime;
  final String? endTime;
  final String? room;
  final String? teacherName;
  final String? reason;

  /// Makeup: the date it replaces. Cancelled: where it moved to, if anywhere.
  final String? makeupFor;
  final String? movedTo;
  final String? movedToStart;

  const CrmBuoiChange({
    required this.date,
    required this.sectionCode,
    required this.status,
    this.subjectName = '',
    this.plannedStart,
    this.startTime,
    this.endTime,
    this.room,
    this.teacherName,
    this.reason,
    this.makeupFor,
    this.movedTo,
    this.movedToStart,
  });

  bool get isCancelled => status == 'cancelled';
  bool get isMakeup => status == 'makeup';

  /// "dd/mm" of a YYYY-MM-DD value, or ''.
  static String ddmm(String? iso) =>
      iso != null && iso.length >= 10 ? '${iso.substring(8, 10)}/${iso.substring(5, 7)}' : '';

  factory CrmBuoiChange.fromJson(Map<String, dynamic> j) => CrmBuoiChange(
    date: j['date']?.toString() ?? '',
    sectionCode: j['section_code']?.toString() ?? '',
    status: j['status']?.toString() ?? '',
    subjectName: j['subject_name']?.toString() ?? '',
    plannedStart: j['planned_start']?.toString(),
    startTime: j['start_time']?.toString(),
    endTime: j['end_time']?.toString(),
    room: j['room']?.toString(),
    teacherName: j['teacher_name']?.toString(),
    reason: j['reason']?.toString(),
    makeupFor: j['makeup_for']?.toString(),
    movedTo: j['moved_to']?.toString(),
    movedToStart: j['moved_to_start']?.toString(),
  );
}
