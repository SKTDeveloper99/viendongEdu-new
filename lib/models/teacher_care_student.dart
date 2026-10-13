/// Một sinh viên trong danh sách theo dõi của giảng viên —
/// `GET /api/student-care` (mỗi phần tử `students[]`) và
/// `GET /api/student-care/student/:mssv` (`student`). Code CRM:
/// `lib/student-care-service.js` (crm-clean).
///
/// LUẬT MỘT GIỌNG (M-54): giảng viên thấy MỘT con số cho mỗi mục, không có
/// chữ nào nói số đó từ đâu ra. Tiền chỉ đọc từ `dossier.money_one`; thiếu
/// hoặc không đủ số → [CareMoney.unknown] ("Đang đối chiếu"), không bao giờ
/// đoán, không bao giờ hiện một phần. `dossier.money` (sổ nội bộ cho nhân
/// viên) KHÔNG được đọc ở đây.
library;

num? _num(Object? v) {
  if (v is num) return v.isFinite ? v : null;
  if (v is String) {
    final n = num.tryParse(v.trim());
    return (n != null && n.isFinite) ? n : null;
  }
  return null;
}

int? _count(Object? v) {
  final n = _num(v);
  return n != null && n >= 0 && n == n.roundToDouble() ? n.toInt() : null;
}

String? _str(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

/// Học phí theo `dossier.money_one`. Hoặc biết đủ cả ba số, hoặc không biết.
class CareMoney {
  final bool known;
  final num? owedTotal;
  final num? paid;
  final num? balance;

  /// Còn nợ tính tới hạn giữa kỳ — chỉ khi máy chủ nói `owes: true`.
  final bool owes;
  final DateTime? asOf;
  final bool stale;

  bool get overpaid => known && balance == 0 && paid! > owedTotal!;

  const CareMoney._(
    this.known,
    this.owedTotal,
    this.paid,
    this.balance,
    this.owes,
    this.asOf,
    this.stale,
  );

  static const unknown = CareMoney._(
    false,
    null,
    null,
    null,
    false,
    null,
    false,
  );

  factory CareMoney.fromJson(Object? raw) {
    if (raw is! Map) return unknown;
    final j = raw.cast<String, dynamic>();
    if (j['money_known'] != true) return unknown;
    final owed = _num(j['owedTotal']);
    final paid = _num(j['paid']);
    final bal = _num(j['balance']);
    if ([
      owed,
      paid,
      bal,
    ].any((n) => n == null || n < 0 || n != n.roundToDouble())) {
      return unknown;
    }
    return CareMoney._(
      true,
      owed,
      paid,
      bal,
      j['owes'] == true,
      DateTime.tryParse('${j['as_of'] ?? ''}'),
      j['stale'] == true,
    );
  }

  Map<String, dynamic> toJson() => known
      ? {
          'money_known': true,
          'owedTotal': owedTotal,
          'paid': paid,
          'balance': balance,
          'owes': owes,
          'as_of': ?asOf?.toUtc().toIso8601String(),
          'stale': stale,
        }
      : {'money_known': false};
}

/// Một lớp học phần của sinh viên (`dossier.sections[]`).
class CareSection {
  final String sectionId;
  final String? sectionCode;
  final String? subjectName;
  final int? present;
  final int? absent;

  /// Buổi đã dạy mà chưa có dấu điểm danh: "Chờ giáo viên xác nhận" —
  /// không bao giờ tính là vắng.
  final int? unrecorded;

  /// Buổi có hai dấu trái nhau — không tính có mặt, không tính vắng.
  final int? conflicts;
  final num? midterm;
  final num? finalScore;
  final bool scoresReadable;

  bool get attendanceKnown =>
      present != null &&
      absent != null &&
      unrecorded != null &&
      conflicts != null;

  const CareSection({
    required this.sectionId,
    this.sectionCode,
    this.subjectName,
    this.present = 0,
    this.absent = 0,
    this.unrecorded = 0,
    this.conflicts = 0,
    this.midterm,
    this.finalScore,
    this.scoresReadable = true,
  });

  factory CareSection.fromJson(Map<String, dynamic> j) => CareSection(
    sectionId: _str(j['section_id']) ?? '',
    sectionCode: _str(j['section_code']),
    subjectName: _str(j['subject_name']),
    present: _count(j['present']),
    absent: _count(j['absent']),
    unrecorded: _count(j['unrecorded']),
    conflicts: _count(j['conflicts']),
    midterm: _num(j['midterm_score']),
    finalScore: _num(j['final_score']),
    scoresReadable:
        j['scores_readable'] != false &&
        j.containsKey('midterm_score') &&
        j.containsKey('final_score') &&
        (j['midterm_score'] == null || _num(j['midterm_score']) != null) &&
        (j['final_score'] == null || _num(j['final_score']) != null),
  );

  Map<String, dynamic> toJson() => {
    'section_id': sectionId,
    'section_code': ?sectionCode,
    'subject_name': ?subjectName,
    'present': present,
    'absent': absent,
    'unrecorded': unrecorded,
    'conflicts': conflicts,
    'midterm_score': midterm,
    'final_score': finalScore,
    'scores_readable': scoresReadable,
  };
}

class TeacherCareStudent {
  final String mssv;
  final String name;
  final String? classCode;
  final List<CareSection> sections;

  /// `section_id` của các lớp chính giảng viên này dạy.
  final List<String> mySectionIds;
  final CareMoney money;

  /// `dossier.freshness` — false/thiếu nghĩa là dữ liệu nguồn chưa cập nhật
  /// trong 26 giờ qua, nên mục đó hiện "Đang đối chiếu".
  final bool attendanceFresh;
  final bool gradesFresh;

  /// Có ca "môn chưa đạt" đang mở (`checks[].kind == 'progression'`).
  final bool hasFailedSubjects;

  const TeacherCareStudent({
    required this.mssv,
    required this.name,
    this.classCode,
    this.sections = const [],
    this.mySectionIds = const [],
    this.money = CareMoney.unknown,
    this.attendanceFresh = false,
    this.gradesFresh = false,
    this.hasFailedSubjects = false,
  });

  factory TeacherCareStudent.fromJson(Map<String, dynamic> j) {
    final d = _map(j['dossier']);
    final fresh = _map(d['freshness']);
    final checks = j['checks'] is List ? j['checks'] as List : const [];
    return TeacherCareStudent(
      mssv: _str(j['mssv']) ?? '',
      name: _str(d['full_name']) ?? _str(j['full_name']) ?? '',
      classCode: _str(d['class_code']),
      sections: (d['sections'] is List ? d['sections'] as List : const [])
          .whereType<Map>()
          .map((s) => CareSection.fromJson(s.cast<String, dynamic>()))
          .where((s) => s.sectionId.isNotEmpty)
          .toList(),
      mySectionIds:
          (j['can_review_sections'] is List
                  ? j['can_review_sections'] as List
                  : const [])
              .map((e) => e.toString())
              .toList(),
      money: CareMoney.fromJson(d['money_one']),
      attendanceFresh: fresh['attendance'] == true,
      gradesFresh: fresh['grades'] == true,
      hasFailedSubjects: checks.whereType<Map>().any(
        (c) => c['kind'] == 'progression',
      ),
    );
  }

  /// Dạng gọn để lưu bản offline: chỉ những gì màn hình dùng — đọc lại bằng
  /// [TeacherCareStudent.fromJson].
  Map<String, dynamic> toJson() => {
    'mssv': mssv,
    'can_review_sections': mySectionIds,
    'checks': [
      if (hasFailedSubjects) {'kind': 'progression'},
    ],
    'dossier': {
      'full_name': name,
      'class_code': ?classCode,
      'sections': sections.map((s) => s.toJson()).toList(),
      'money_one': money.toJson(),
      'freshness': {'attendance': attendanceFresh, 'grades': gradesFresh},
    },
  };

  CareSection? section(String sectionId) {
    for (final s in sections) {
      if (s.sectionId == sectionId) return s;
    }
    return null;
  }

  /// Tổng số buổi vắng trong các lớp giảng viên dạy (chỉ khi dữ liệu mới).
  int get myAbsences => !attendanceFresh
      ? 0
      : sections
            .where(
              (s) => s.attendanceKnown && mySectionIds.contains(s.sectionId),
            )
            .fold(0, (sum, s) => sum + (s.absent ?? 0));

  /// Lý do "Cần chú ý" — rỗng nghĩa là không cần chú ý.
  List<String> get attentionReasons => [
    if (myAbsences > 0) 'Vắng $myAbsences buổi',
    if (gradesFresh && hasFailedSubjects) 'Có môn chưa đạt',
  ];

  bool get needsAttention => attentionReasons.isNotEmpty;
}
