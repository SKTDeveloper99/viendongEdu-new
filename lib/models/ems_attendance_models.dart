/// Một buổi dạy trong sổ lịch bền vững của EMS.
class EmsSession {
  final String? scheduleSessionId;
  final String sectionId;
  final String sectionCode;
  final String? subjectName;
  final String? room;
  final String sessionDate;
  final String? startTime;
  final String? endTime;
  final int rosterSize;
  final int markedCount;
  final String sessionKey;
  final String reportState;

  const EmsSession({
    this.scheduleSessionId,
    required this.sectionId,
    required this.sectionCode,
    required this.sessionDate,
    required this.sessionKey,
    this.subjectName,
    this.room,
    this.startTime,
    this.endTime,
    this.rosterSize = 0,
    this.markedCount = 0,
    this.reportState = 'open',
  });

  bool get isMarked => markedCount > 0;

  String get timeLabel => (startTime == null || endTime == null)
      ? 'Chưa có giờ'
      : '$startTime – $endTime';

  factory EmsSession.fromJson(Map<String, dynamic> j) => EmsSession(
    scheduleSessionId: j['schedule_session_id']?.toString(),
    sectionId: j['section_id']?.toString() ?? '',
    sectionCode: j['section_code']?.toString() ?? '',
    subjectName: j['subject_name']?.toString(),
    room: j['room']?.toString(),
    sessionDate: j['session_date']?.toString() ?? '',
    startTime: j['start_time']?.toString(),
    endTime: j['end_time']?.toString(),
    // count(*) của Postgres là bigint — có thể về dạng chuỗi. Parse cho chắc.
    rosterSize: int.tryParse('${j['roster_size'] ?? 0}') ?? 0,
    markedCount: int.tryParse('${j['marked_count'] ?? 0}') ?? 0,
    sessionKey: j['session_key']?.toString() ?? '',
    reportState: j['report_state']?.toString() ?? 'open',
  );

  Map<String, dynamic> toJson() => {
    'schedule_session_id': ?scheduleSessionId,
    'section_id': sectionId,
    'section_code': sectionCode,
    'subject_name': ?subjectName,
    'room': ?room,
    'session_date': sessionDate,
    'start_time': ?startTime,
    'end_time': ?endTime,
    'roster_size': rosterSize,
    'marked_count': markedCount,
    'session_key': sessionKey,
    'report_state': reportState,
  };
}

/// Một dòng trong danh sách lớp.
///
/// [status] null nghĩa là CHƯA ĐIỂM DANH — không phải vắng. Đây là khác biệt
/// quan trọng nhất so với IMS và giao diện phải thể hiện đúng như vậy.
class EmsRosterStudent {
  final String mssv;
  final String fullName;
  final String? classCode;
  final bool inScope;
  final String? status;
  final String? note;
  final bool scanned;
  final DateTime? scannedAt;
  final int? punchId;

  const EmsRosterStudent({
    required this.mssv,
    required this.fullName,
    this.classCode,
    this.inScope = false,
    this.status,
    this.note,
    this.scanned = false,
    this.scannedAt,
    this.punchId,
  });

  factory EmsRosterStudent.fromJson(Map<String, dynamic> j) => EmsRosterStudent(
    mssv: j['mssv']?.toString() ?? '',
    fullName: j['full_name']?.toString() ?? '',
    classCode: j['class_code']?.toString(),
    inScope: j['in_scope'] == true,
    status: j['status']?.toString(),
    note: j['note']?.toString(),
    scanned: j['scanned'] == true,
    scannedAt: DateTime.tryParse(j['scanned_at']?.toString() ?? '')?.toLocal(),
    // punch_id là bigint của Postgres — tuỳ driver trả về SỐ hoặc CHUỖI. Ép
    // 'as num' sẽ nổ khi nó là chuỗi. Parse từ toString() cho chắc.
    punchId: j['punch_id'] == null
        ? null
        : int.tryParse(j['punch_id'].toString()),
  );

  Map<String, dynamic> toJson() => {
    'mssv': mssv,
    'full_name': fullName,
    'class_code': ?classCode,
    'in_scope': inScope,
    'status': ?status,
    'note': ?note,
    'scanned': scanned,
    'scanned_at': ?scannedAt?.toIso8601String(),
    'punch_id': ?punchId,
  };
}

class EmsRoster {
  final String sessionKey;
  final List<EmsRosterStudent> students;
  final int unmatchedScans;

  /// Lần gần nhất EMS kéo được lượt quẹt cổng từ máy chấm công (null = chưa
  /// bao giờ). Giáo viên nhìn giờ này để biết danh sách "đã quẹt" cũ tới đâu.
  final DateTime? scanSyncedAt;

  const EmsRoster({
    required this.sessionKey,
    required this.students,
    this.unmatchedScans = 0,
    this.scanSyncedAt,
  });

  factory EmsRoster.fromJson(Map<String, dynamic> j) => EmsRoster(
    sessionKey: j['session_key']?.toString() ?? '',
    scanSyncedAt: DateTime.tryParse(j['scan_synced_at']?.toString() ?? ''),
    students: (j['students'] is List)
        ? (j['students'] as List)
              .whereType<Map<String, dynamic>>()
              .map(EmsRosterStudent.fromJson)
              .toList()
        : const [],
    unmatchedScans: (j['unmatched_scans'] is List)
        ? (j['unmatched_scans'] as List).length
        : 0,
  );
}

class EmsMark {
  final String mssv;
  final String status; // 'present' | 'absent'
  final String? note;
  final int? punchId;
  const EmsMark({
    required this.mssv,
    required this.status,
    this.note,
    this.punchId,
  });

  Map<String, dynamic> toJson() => {
    'mssv': mssv,
    'status': status,
    'note': ?note,
    'punch_id': ?punchId,
  };
}

class EmsSaveResult {
  final int saved;
  final int inserted;
  final int updated;
  final bool late;
  final DateTime? deadline;
  final List<String> overriddenPunches;

  const EmsSaveResult({
    this.saved = 0,
    this.inserted = 0,
    this.updated = 0,
    this.late = false,
    this.deadline,
    this.overriddenPunches = const [],
  });

  factory EmsSaveResult.fromJson(Map<String, dynamic> j) => EmsSaveResult(
    saved: (j['saved'] as num?)?.toInt() ?? 0,
    inserted: (j['inserted'] as num?)?.toInt() ?? 0,
    updated: (j['updated'] as num?)?.toInt() ?? 0,
    late: j['late'] == true,
    deadline: DateTime.tryParse(j['deadline']?.toString() ?? '')?.toLocal(),
    overriddenPunches: (j['overridden_punches'] is List)
        ? (j['overridden_punches'] as List).map((e) => e.toString()).toList()
        : const [],
  );
}

/// Một dòng điểm danh EMS mà học viên tự xem.
class EmsStudentMark {
  final String? sessionKey;
  final String? sessionDate;
  final String? status;
  final String? subjectName;
  final String? sectionCode;
  final String? note;
  final String? startTime;
  final String? endTime;
  final DateTime? arrivedAt;
  final bool? arrivalOnTime;

  /// 'ems' (teacher/scanner record, authoritative) or 'ims' (mirrored history).
  final String? source;

  const EmsStudentMark({
    this.sessionKey,
    this.sessionDate,
    this.status,
    this.subjectName,
    this.sectionCode,
    this.note,
    this.startTime,
    this.endTime,
    this.arrivedAt,
    this.arrivalOnTime,
    this.source,
  });

  factory EmsStudentMark.fromJson(Map<String, dynamic> j) => EmsStudentMark(
    sessionKey: j['session_key']?.toString(),
    sessionDate: j['session_date']?.toString(),
    status: j['status']?.toString(),
    subjectName: j['subject_name']?.toString(),
    sectionCode: j['section_code']?.toString(),
    note: j['note']?.toString(),
    startTime: j['start_time']?.toString(),
    endTime: j['end_time']?.toString(),
    arrivedAt: DateTime.tryParse(j['arrived_at']?.toString() ?? '')?.toLocal(),
    arrivalOnTime: j['arrival_on_time'] as bool?,
    source: j['source']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'session_key': ?sessionKey,
    'session_date': ?sessionDate,
    'status': ?status,
    'source': ?source,
    'subject_name': ?subjectName,
    'section_code': ?sectionCode,
    'note': ?note,
    'start_time': ?startTime,
    'end_time': ?endTime,
    'arrived_at': ?arrivedAt?.toIso8601String(),
    'arrival_on_time': ?arrivalOnTime,
  };

  /// Ngày buổi học dạng dd/MM/yyyy.
  ///
  /// session_date của EMS là một Postgres DATE, về tới đây dưới dạng
  /// 'YYYY-MM-DDT00:00:00.000Z'. KHÔNG đưa qua DateTime.parse().toLocal() —
  /// nửa đêm UTC quy về giờ Việt Nam (+7) sẽ nhảy về NGÀY HÔM TRƯỚC. Đây là
  /// một mốc lịch, không phải một thời điểm: đọc thẳng Y-M-D từ chuỗi.
  String get sessionDateVN {
    final s = sessionDate ?? '';
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    return m == null ? s : '${m.group(3)}/${m.group(2)}/${m.group(1)}';
  }
}
